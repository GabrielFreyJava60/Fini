"""Hybrid logical clock: '<13-digit millis>-<4-digit counter>-<node>' sorts lexicographically."""
from __future__ import annotations

import threading
import time


def parse(ts: str) -> tuple[int, int, str]:
    ms, ctr, node = ts.split("-", 2)
    return int(ms), int(ctr), node


def fmt(ms: int, ctr: int, node: str) -> str:
    return f"{ms:013d}-{ctr:04d}-{node}"


class HybridLogicalClock:
    def __init__(self, node: str, now=lambda: int(time.time() * 1000)):
        self.node, self._now, self._ms, self._ctr = node, now, 0, 0
        self._lock = threading.Lock()

    def tick(self) -> str:
        with self._lock:
            wall = self._now()
            if wall > self._ms:
                self._ms, self._ctr = wall, 0
            else:
                self._ctr += 1
            return fmt(self._ms, self._ctr, self.node)

    def receive(self, remote: str) -> str:
        rms, rctr, _ = parse(remote)
        with self._lock:
            wall = self._now()
            m = max(wall, self._ms, rms)
            if m == self._ms == rms:
                self._ctr = max(self._ctr, rctr) + 1
            elif m == self._ms:
                self._ctr += 1
            elif m == rms:
                self._ctr = rctr + 1
            else:
                self._ctr = 0
            self._ms = m
            return fmt(self._ms, self._ctr, self.node)
