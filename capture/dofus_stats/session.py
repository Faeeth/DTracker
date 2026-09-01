"""Assemblage du pipeline : octets bruts -> messages Dofus identifies.

    Source -> dissect -> reassemblage TCP -> deframing -> enveloppe protobuf

Une seule porte d'entree pour le direct et le differe : tout ce qui suit ignore
d'ou viennent les octets.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Iterator

from .capture.source import Frame
from .net.dissect import FlowKey, dissect
from .net.identify import Client, ClientIndex
from .net.reassembler import TCPReassembler
from .protocol.envelope import Envelope, parse
from .protocol.framing import Deframer

GAME_PORT = 5555


@dataclass
class Observed:
    """Un message Dofus, replace dans son contexte."""
    env: Envelope
    flow: FlowKey
    client: Client | None
    connection: tuple

    @property
    def who(self) -> str:
        return self.client.character if self.client else f"port{self.local_port}"

    @property
    def local_port(self) -> int:
        return self.flow.dport if self.env.from_server else self.flow.sport

    @property
    def server(self) -> str:
        return self.flow.src if self.env.from_server else self.flow.dst


@dataclass
class Stats:
    frames: int = 0
    segments: int = 0
    payload_bytes: int = 0
    messages: int = 0
    parse_errors: int = 0
    gaps: int = 0
    connections: set = field(default_factory=set)


class Session:
    def __init__(self, port: int = GAME_PORT, clients: list[Client] | None = None):
        self.port = port
        self.index = ClientIndex(clients)
        self.reasm = TCPReassembler()
        self.deframers: dict[FlowKey, Deframer] = {}
        self.stats = Stats()

    def run(self, frames: Iterator[Frame]) -> Iterator[Observed]:
        for frame in frames:
            self.stats.frames += 1
            seg = dissect(frame.ts, frame.data, frame.linktype, self.port or None)
            if seg is None:
                continue
            self.stats.segments += 1
            self.stats.payload_bytes += len(seg.payload)
            self.stats.connections.add(seg.flow.connection_id())

            for block in self.reasm.feed(seg):
                yield from self._on_bytes(block)

    def _on_bytes(self, block) -> Iterator[Observed]:
        deframer = self.deframers.get(block.flow)
        if deframer is None:
            deframer = self.deframers[block.flow] = Deframer()
        if block.gap_before:
            self.stats.gaps += 1

        from_server = block.flow.sport == self.port
        local_port = block.flow.dport if from_server else block.flow.sport
        client = self.index.resolve(local_port)
        conn = block.flow.connection_id()

        for raw in deframer.feed(block.data, block.ts, block.gap_before):
            env = parse(raw.body, raw.ts, from_server)
            self.stats.messages += 1
            if env.error:
                self.stats.parse_errors += 1
            yield Observed(env, block.flow, client, conn)

    def report(self) -> str:
        s = self.stats
        lines = [
            f"trames={s.frames}  segments={s.segments}  octets={s.payload_bytes}",
            f"connexions={len(s.connections)}  messages={s.messages}"
            f"  erreurs={s.parse_errors}  trous={s.gaps}",
        ]
        for flow, d in sorted(self.deframers.items(), key=lambda kv: str(kv[0])):
            state = self.reasm.states.get(flow)
            rest = len(d.buf)
            lines.append(
                f"  {flow}: {d.messages} msgs, reste={rest}o, resync={d.resyncs},"
                f" perdus={d.dropped_bytes}o"
                + (f", trous_tcp={state.gaps}" if state and state.gaps else "")
            )
        return "\n".join(lines)
