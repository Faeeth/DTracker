"""Diffusion des evenements vers un consommateur exterieur.

Deux transports, choisis a l'appel :

  - `NdjsonSink` ecrit une ligne JSON par evenement sur un flux. C'est le mode
    par defaut : il n'ouvre aucun port, se consomme depuis n'importe quel
    langage en lisant une sortie standard, et tient trois ordres de grandeur
    au-dessus du debit reel du jeu.

  - `WebSocketSink` ouvre un serveur local auquel plusieurs consommateurs
    peuvent s'abonner simultanement. Utile pour une interface web, ou lorsque
    l'application ne peut pas lancer la bibliotheque en sous-processus.

Le serveur WebSocket est implemente ici meme, sans dependance : le protocole se
reduit, pour ce que nous en faisons, a une poignee de main HTTP puis a un
encadrement de trames texte.
"""
from __future__ import annotations

import base64
import hashlib
import json
import socket
import struct
import sys
import threading
from typing import Any, Callable, Iterable, TextIO

from .events import Event
from .serialize import to_json

WS_MAGIC = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"


class Sink:
    """Destination d'evenements."""

    def emit(self, event: Event) -> None:
        raise NotImplementedError

    def close(self) -> None:
        pass

    def __enter__(self) -> "Sink":
        return self

    def __exit__(self, *exc) -> None:
        self.close()


class NdjsonSink(Sink):
    """Une ligne JSON par evenement.

    `flush` immediat par defaut : un consommateur qui lit au fil de l'eau ne
    doit pas attendre que le tampon se remplisse, sous peine de recevoir les
    evenements par paquets avec plusieurs secondes de retard.
    """

    def __init__(self, stream: TextIO | None = None, flush: bool = True,
                 drop_none: bool = True):
        self.stream = stream if stream is not None else sys.stdout
        self.flush = flush
        self.drop_none = drop_none

    def emit(self, event: Event) -> None:
        self.stream.write(to_json(event, drop_none=self.drop_none))
        self.stream.write("\n")
        if self.flush:
            self.stream.flush()


class WebSocketSink(Sink):
    """Serveur WebSocket local diffusant les evenements aux clients connectes.

    Les clients vont et viennent sans interrompre la lecture : une ecriture qui
    echoue retire simplement le client de la liste.
    """

    def __init__(self, host: str = "127.0.0.1", port: int = 8765,
                 drop_none: bool = True):
        self.host = host
        self.port = port
        self.drop_none = drop_none
        self._clients: list[socket.socket] = []
        self._lock = threading.Lock()
        self._server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self._server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self._server.bind((host, port))
        self._server.listen(8)
        self._running = True
        self._thread = threading.Thread(target=self._accept_loop, daemon=True)
        self._thread.start()

    @property
    def clients(self) -> int:
        with self._lock:
            return len(self._clients)

    def _accept_loop(self) -> None:
        while self._running:
            try:
                conn, _ = self._server.accept()
            except OSError:
                return
            try:
                if self._handshake(conn):
                    with self._lock:
                        self._clients.append(conn)
                else:
                    conn.close()
            except OSError:
                conn.close()

    @staticmethod
    def _handshake(conn: socket.socket) -> bool:
        """Poignee de main HTTP du protocole WebSocket."""
        conn.settimeout(5)
        data = b""
        while b"\r\n\r\n" not in data:
            chunk = conn.recv(4096)
            if not chunk:
                return False
            data += chunk
            if len(data) > 65536:
                return False
        key = None
        for line in data.decode("latin-1").split("\r\n"):
            if line.lower().startswith("sec-websocket-key:"):
                key = line.split(":", 1)[1].strip()
        if not key:
            return False
        accept = base64.b64encode(
            hashlib.sha1((key + WS_MAGIC).encode()).digest()).decode()
        conn.sendall(
            b"HTTP/1.1 101 Switching Protocols\r\n"
            b"Upgrade: websocket\r\n"
            b"Connection: Upgrade\r\n"
            b"Sec-WebSocket-Accept: " + accept.encode() + b"\r\n\r\n")
        conn.settimeout(None)
        return True

    @staticmethod
    def _frame(payload: str) -> bytes:
        """Encadre un message texte. Le serveur n'applique pas de masque."""
        data = payload.encode("utf-8")
        header = bytearray([0x81])          # trame finale, opcode texte
        size = len(data)
        if size < 126:
            header.append(size)
        elif size < (1 << 16):
            header.append(126)
            header += struct.pack(">H", size)
        else:
            header.append(127)
            header += struct.pack(">Q", size)
        return bytes(header) + data

    def emit(self, event: Event) -> None:
        with self._lock:
            if not self._clients:
                return
            frame = self._frame(to_json(event, drop_none=self.drop_none))
            vivants = []
            for conn in self._clients:
                try:
                    conn.sendall(frame)
                    vivants.append(conn)
                except OSError:
                    conn.close()
            self._clients = vivants

    def close(self) -> None:
        self._running = False
        with self._lock:
            for conn in self._clients:
                conn.close()
            self._clients = []
        try:
            self._server.close()
        except OSError:
            pass


class CallbackSink(Sink):
    """Appelle une fonction par evenement. Pour un consommateur en Python."""

    def __init__(self, callback: Callable[[Event], None]):
        self.callback = callback

    def emit(self, event: Event) -> None:
        self.callback(event)


class FanOut(Sink):
    """Diffuse vers plusieurs destinations a la fois."""

    def __init__(self, *sinks: Sink):
        self.sinks = list(sinks)

    def emit(self, event: Event) -> None:
        for sink in self.sinks:
            sink.emit(event)

    def close(self) -> None:
        for sink in self.sinks:
            sink.close()


def make_sink(mode: str = "ndjson", **options: Any) -> Sink:
    """Fabrique une destination a partir de son nom.

    `ndjson` par defaut : il suffit au debit reel du jeu et n'ouvre aucun port.
    `websocket` lorsque plusieurs consommateurs doivent s'abonner, ou que
    l'application ne peut pas lancer la bibliotheque en sous-processus.
    """
    if mode == "ndjson":
        return NdjsonSink(**options)
    if mode == "websocket":
        return WebSocketSink(**options)
    if mode == "both":
        port = options.pop("port", 8765)
        host = options.pop("host", "127.0.0.1")
        return FanOut(NdjsonSink(**options), WebSocketSink(host=host, port=port))
    raise ValueError(f"mode de diffusion inconnu : {mode}")


def stream(events: Iterable[Event], sink: Sink) -> int:
    """Deverse un flux d'evenements dans une destination. Rend le compte emis."""
    n = 0
    with sink:
        for event in events:
            sink.emit(event)
            n += 1
    return n
