"""Reassemblage du flux TCP, une direction a la fois.

Le deframing en aval a besoin d'un octet-stream continu et ordonne. On gere donc
le desordre, les retransmissions, les chevauchements et le bouclage des numeros
de sequence sur 32 bits. Les trous non combles sont signales plutot que masques :
un trou silencieux se traduirait en aval par un deframing qui part en vrille.
"""
from __future__ import annotations

from dataclasses import dataclass, field

from .dissect import TCP_FIN, TCP_RST, TCP_SYN, FlowKey, Segment

SEQ_MOD = 1 << 32
SEQ_HALF = 1 << 31


def seq_delta(a: int, b: int) -> int:
    """Distance signee de b vers a, robuste au bouclage 32 bits."""
    d = (a - b) % SEQ_MOD
    return d - SEQ_MOD if d >= SEQ_HALF else d


@dataclass
class DirectionState:
    next_seq: int | None = None
    pending: dict[int, bytes] = field(default_factory=dict)
    pending_bytes: int = 0
    bytes_out: int = 0
    gaps: int = 0
    lost_bytes: int = 0
    started: bool = False
    finished: bool = False


@dataclass
class StreamData:
    """Octets contigus nouvellement disponibles sur une direction."""
    ts: float
    flow: FlowKey
    data: bytes
    gap_before: int = 0     # octets perdus juste avant ce bloc, 0 si continuite


class TCPReassembler:
    """Accumule des segments et rend des blocs d'octets ordonnes par direction."""

    def __init__(self, max_pending_bytes: int = 4 << 20, max_pending_segments: int = 1024):
        self.states: dict[FlowKey, DirectionState] = {}
        self.max_pending_bytes = max_pending_bytes
        self.max_pending_segments = max_pending_segments

    def feed(self, seg: Segment) -> list[StreamData]:
        st = self.states.get(seg.flow)
        if st is None:
            st = self.states[seg.flow] = DirectionState()

        if seg.flags & TCP_SYN:
            # Debut de connexion observe : on connait la sequence initiale exacte.
            st.next_seq = (seg.seq + 1) % SEQ_MOD
            st.started = True
            st.pending.clear()
            st.pending_bytes = 0
            return []

        if not seg.payload:
            if seg.flags & (TCP_FIN | TCP_RST):
                st.finished = True
            return []

        if st.next_seq is None:
            # Capture demarree en cours de connexion : on s'accroche au premier segment vu.
            st.next_seq = seg.seq
            st.started = True

        out: list[StreamData] = []
        delta = seq_delta(seg.seq, st.next_seq)

        if delta < 0:
            # Deja recu en tout ou partie : on ne garde que la portion nouvelle.
            overlap = -delta
            if overlap >= len(seg.payload):
                return []
            payload = seg.payload[overlap:]
            out.append(self._emit(st, seg, payload, 0))
        elif delta == 0:
            out.append(self._emit(st, seg, seg.payload, 0))
        else:
            # Segment en avance : on le met de cote en attendant le manquant.
            if seg.seq not in st.pending:
                st.pending[seg.seq] = seg.payload
                st.pending_bytes += len(seg.payload)
            if (st.pending_bytes > self.max_pending_bytes
                    or len(st.pending) > self.max_pending_segments):
                out.extend(self._force_gap(st, seg.ts, seg.flow))
            return [o for o in out if o is not None] + self._drain(st, seg.ts, seg.flow)

        out.extend(self._drain(st, seg.ts, seg.flow))
        return [o for o in out if o is not None]

    def _emit(self, st: DirectionState, seg: Segment, payload: bytes, gap: int) -> StreamData:
        st.next_seq = (st.next_seq + len(payload)) % SEQ_MOD
        st.bytes_out += len(payload)
        return StreamData(seg.ts, seg.flow, payload, gap)

    def _drain(self, st: DirectionState, ts: float, flow: FlowKey) -> list[StreamData]:
        """Vide les segments en attente devenus contigus."""
        out: list[StreamData] = []
        while True:
            hit = None
            for seq in list(st.pending):
                d = seq_delta(seq, st.next_seq)
                if d <= 0:
                    hit = (seq, d)
                    break
            if hit is None:
                return out
            seq, d = hit
            payload = st.pending.pop(seq)
            st.pending_bytes -= len(payload)
            payload = payload[-d:] if d < 0 else payload
            if not payload:
                continue
            st.next_seq = (st.next_seq + len(payload)) % SEQ_MOD
            st.bytes_out += len(payload)
            out.append(StreamData(ts, flow, payload, 0))

    def _force_gap(self, st: DirectionState, ts: float, flow: FlowKey) -> list[StreamData]:
        """Renonce a attendre : saute au plus ancien segment en attente."""
        target = min(st.pending, key=lambda s: seq_delta(s, st.next_seq))
        lost = seq_delta(target, st.next_seq)
        st.gaps += 1
        st.lost_bytes += max(lost, 0)
        st.next_seq = target
        payload = st.pending.pop(target)
        st.pending_bytes -= len(payload)
        st.next_seq = (st.next_seq + len(payload)) % SEQ_MOD
        st.bytes_out += len(payload)
        return [StreamData(ts, flow, payload, max(lost, 0))]

    def stats(self) -> dict[FlowKey, DirectionState]:
        return self.states
