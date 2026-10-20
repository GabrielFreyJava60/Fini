"""BIP39-style 24-word recovery phrase (256-bit entropy + 8-bit SHA-256 checksum).
Wordlist is the bundled BIP39 English list (sha256 2f5eed53…dbda)."""
from __future__ import annotations

import hashlib
import secrets
from functools import lru_cache
from importlib import resources

WORDLIST_SHA256 = "2f5eed53a4727b4bf8880d8f3f199efc90e58503646d9ff8eff3a2ed3b24dbda"


class RecoveryPhraseError(ValueError):
    pass


@lru_cache(maxsize=1)
def wordlist() -> tuple[str, ...]:
    raw = resources.files("finance.resources").joinpath("bip39_english.txt").read_bytes()
    if hashlib.sha256(raw).hexdigest() != WORDLIST_SHA256:
        raise RecoveryPhraseError("bundled wordlist is corrupted")
    words = tuple(raw.decode().split())
    assert len(words) == 2048
    return words


def entropy_to_phrase(entropy: bytes) -> str:
    if len(entropy) not in (16, 20, 24, 28, 32):
        raise RecoveryPhraseError("entropy must be 128..256 bits")
    cs_bits = len(entropy) * 8 // 32
    bits = int.from_bytes(entropy, "big") << cs_bits | (hashlib.sha256(entropy).digest()[0] >> (8 - cs_bits))
    n_words = (len(entropy) * 8 + cs_bits) // 11
    wl = wordlist()
    return " ".join(wl[(bits >> (11 * (n_words - 1 - i))) & 0x7FF] for i in range(n_words))


def generate_phrase(words: int = 24) -> str:
    return entropy_to_phrase(secrets.token_bytes({12: 16, 15: 20, 18: 24, 21: 28, 24: 32}[words]))


def phrase_to_entropy(phrase: str) -> bytes:
    words = phrase.strip().lower().split()
    if len(words) not in (12, 15, 18, 21, 24):
        raise RecoveryPhraseError("phrase must have 12-24 words")
    index = {w: i for i, w in enumerate(wordlist())}
    try:
        bits = 0
        for w in words:
            bits = bits << 11 | index[w]
    except KeyError as e:
        raise RecoveryPhraseError(f"unknown word: {e.args[0]}") from None
    cs_bits = len(words) * 11 // 33
    ent_len = (len(words) * 11 - cs_bits) // 8
    entropy = (bits >> cs_bits).to_bytes(ent_len, "big")
    if bits & ((1 << cs_bits) - 1) != hashlib.sha256(entropy).digest()[0] >> (8 - cs_bits):
        raise RecoveryPhraseError("checksum mismatch (typo in phrase?)")
    return entropy
