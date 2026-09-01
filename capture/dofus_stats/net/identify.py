"""Rattachement d'une connexion TCP au personnage qui la porte.

Windows expose le PID proprietaire de chaque socket, et le titre de la fenetre
Dofus contient le nom du personnage : "Kaska-nini - Eniripsa - 3.6.10.11 - Release".
En croisant les deux, chaque flux capture porte un nom plutot qu'un numero de port.

Le port local d'une session ne survit pas a une reconnexion : pour une capture
differee on enregistre un instantane au moment de la capture, qu'on relit ensuite.
"""
from __future__ import annotations

import json
import os
import subprocess
from dataclasses import dataclass

PS_SNAPSHOT = r"""
$procs = @{}
Get-Process -Name Dofus -ErrorAction SilentlyContinue | ForEach-Object { $procs[[string]$_.Id] = $_.MainWindowTitle }
$ids = $procs.Keys
Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue |
  Where-Object { $ids -contains [string]$_.OwningProcess } |
  ForEach-Object {
    [PSCustomObject]@{
      pid        = $_.OwningProcess
      title      = $procs[[string]$_.OwningProcess]
      localAddr  = $_.LocalAddress
      localPort  = $_.LocalPort
      remoteAddr = $_.RemoteAddress
      remotePort = $_.RemotePort
    }
  } | ConvertTo-Json -Depth 3 -Compress
"""


@dataclass(frozen=True)
class Client:
    pid: int
    character: str
    klass: str
    version: str
    local_addr: str
    local_port: int
    remote_addr: str
    remote_port: int

    @property
    def label(self) -> str:
        return self.character or f"pid{self.pid}"


def parse_title(title: str) -> tuple[str, str, str]:
    """"Kaska-nini - Eniripsa - 3.6.10.11 - Release" -> (perso, classe, version)."""
    parts = [p.strip() for p in (title or "").split(" - ")]
    while len(parts) < 3:
        parts.append("")
    return parts[0], parts[1], parts[2]


def snapshot() -> list[Client]:
    """Interroge Windows sur les connexions Dofus en cours."""
    try:
        res = subprocess.run(
            ["powershell", "-NoProfile", "-NonInteractive", "-Command", PS_SNAPSHOT],
            capture_output=True, text=True, timeout=25,
        )
    except (OSError, subprocess.TimeoutExpired):
        return []
    return _from_json(res.stdout.strip())


def load(path: str) -> list[Client]:
    if not os.path.exists(path):
        return []
    with open(path, "r", encoding="utf-8-sig") as fh:
        return _from_json(fh.read())


def save(clients: list[Client], path: str) -> None:
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    rows = [{"pid": c.pid, "title": f"{c.character} - {c.klass} - {c.version}",
             "localAddr": c.local_addr, "localPort": c.local_port,
             "remoteAddr": c.remote_addr, "remotePort": c.remote_port} for c in clients]
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(rows, fh, indent=2, ensure_ascii=False)


def _from_json(text: str) -> list[Client]:
    if not text:
        return []
    try:
        rows = json.loads(text)
    except json.JSONDecodeError:
        return []
    if isinstance(rows, dict):
        rows = [rows]
    out = []
    for r in rows:
        char, klass, version = parse_title(r.get("title", ""))
        out.append(Client(
            pid=int(r.get("pid") or r.get("pid_") or 0),
            character=char, klass=klass, version=version,
            local_addr=str(r.get("localAddr", "")), local_port=int(r.get("localPort", 0)),
            remote_addr=str(r.get("remoteAddr", "")), remote_port=int(r.get("remotePort", 0)),
        ))
    return out


class ClientIndex:
    """Resout un port local vers le personnage correspondant."""

    def __init__(self, clients: list[Client] | None = None):
        self.by_port: dict[int, Client] = {}
        for c in clients or []:
            self.by_port[c.local_port] = c

    def resolve(self, local_port: int) -> Client | None:
        return self.by_port.get(local_port)

    def label(self, local_port: int) -> str:
        c = self.by_port.get(local_port)
        return c.label if c else f"port{local_port}"

    def __bool__(self) -> bool:
        return bool(self.by_port)
