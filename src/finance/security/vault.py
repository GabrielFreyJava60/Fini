"""Key hierarchy (mirrors the Swift VaultCrypto):
    recovery entropy --HKDF-SHA256--> KEK
    KEK --AES-KeyWrap--> wrapped DEK (stored in Keychain / settings)
    DEK --AES-256-GCM (AAD = record identity)--> payloads & backups
Passphrase-protected exports use scrypt instead of HKDF (low-entropy input)."""
from __future__ import annotations

import json
import os
import struct

from cryptography.exceptions import InvalidTag
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.hkdf import HKDF
from cryptography.hazmat.primitives.kdf.scrypt import Scrypt
from cryptography.hazmat.primitives.keywrap import InvalidUnwrap, aes_key_unwrap, aes_key_wrap

MAGIC = b"FINV1"
SCRYPT_N, SCRYPT_R, SCRYPT_P = 2**15, 8, 1  # ~32 MB; tuned for iPhone memory limits


class VaultError(Exception):
    pass


def new_dek() -> bytes:
    return AESGCM.generate_key(bit_length=256)


def derive_kek(recovery_entropy: bytes, salt: bytes) -> bytes:
    return HKDF(hashes.SHA256(), 32, salt, b"finance.vault.kek.v1").derive(recovery_entropy)


def derive_passphrase_key(passphrase: str, salt: bytes, n: int = SCRYPT_N) -> bytes:
    return Scrypt(salt=salt, length=32, n=n, r=SCRYPT_R, p=SCRYPT_P).derive(passphrase.encode())


def wrap(dek: bytes, kek: bytes) -> bytes:
    return aes_key_wrap(kek, dek)


def unwrap(wrapped: bytes, kek: bytes) -> bytes:
    try:
        return aes_key_unwrap(kek, wrapped)
    except InvalidUnwrap as e:
        raise VaultError("wrong recovery phrase or corrupted key") from e


def _aad(record_type: str, record_name: str, version: int) -> bytes:
    return f"{record_type}|{record_name}|v{version}".encode()


class VaultCrypto:
    def __init__(self, key_id: str, dek: bytes):
        if len(dek) != 32:
            raise VaultError("DEK must be 256-bit")
        self.key_id, self._aes = key_id, AESGCM(dek)

    def seal(self, plaintext: bytes, record_type: str, record_name: str, version: int = 1) -> dict:
        nonce = os.urandom(12)
        ct = self._aes.encrypt(nonce, plaintext, _aad(record_type, record_name, version))
        return {"payload_version": version, "key_id": self.key_id, "sealed": (nonce + ct).hex()}

    def open(self, env: dict, record_type: str, record_name: str) -> bytes:
        if env.get("key_id") != self.key_id:
            raise VaultError(f"unknown key {env.get('key_id')}")
        blob = bytes.fromhex(env["sealed"])
        try:
            return self._aes.decrypt(blob[:12], blob[12:], _aad(record_type, record_name, env["payload_version"]))
        except InvalidTag as e:
            raise VaultError("tampered or wrong record") from e


def encrypt_backup(data: bytes, passphrase: str, n: int = SCRYPT_N) -> bytes:
    """Self-contained file: MAGIC | n(u32) | salt(16) | nonce(12) | ciphertext+tag."""
    salt, nonce = os.urandom(16), os.urandom(12)
    key = derive_passphrase_key(passphrase, salt, n)
    header = MAGIC + struct.pack(">I", n) + salt
    return header + nonce + AESGCM(key).encrypt(nonce, data, header)


def decrypt_backup(blob: bytes, passphrase: str) -> bytes:
    if not blob.startswith(MAGIC) or len(blob) < 5 + 4 + 16 + 12 + 16:
        raise VaultError("not a finance backup")
    (n,) = struct.unpack(">I", blob[5:9])
    salt, nonce, ct = blob[9:25], blob[25:37], blob[37:]
    try:
        return AESGCM(derive_passphrase_key(passphrase, salt, n)).decrypt(nonce, ct, blob[:25])
    except InvalidTag as e:
        raise VaultError("wrong passphrase or corrupted backup") from e


def export_ledger(repo, passphrase: str, n: int = SCRYPT_N) -> bytes:
    rows = [dict(r) for r in repo.c.execute("SELECT * FROM txn")]
    cats = [dict(r) for r in repo.c.execute("SELECT * FROM category")]
    return encrypt_backup(json.dumps({"v": 1, "txn": rows, "category": cats}, ensure_ascii=False).encode(), passphrase, n)
