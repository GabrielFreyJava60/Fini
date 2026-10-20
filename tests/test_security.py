import pytest

from finance.security import recovery, vault
from finance.security.keychain import keychain


def test_bip39_vector():
    # Official BIP39 test vector (all-zero 256-bit entropy)
    p = recovery.entropy_to_phrase(bytes(32))
    assert p == " ".join(["abandon"] * 23 + ["art"])
    assert recovery.phrase_to_entropy(p) == bytes(32)


def test_generate_round_trip_and_checksum():
    p = recovery.generate_phrase()
    assert len(p.split()) == 24
    e = recovery.phrase_to_entropy(p)
    words = p.split(); words[0] = "zoo" if words[0] != "zoo" else "abandon"
    with pytest.raises(recovery.RecoveryPhraseError):
        recovery.phrase_to_entropy(" ".join(words))


def test_key_hierarchy_and_aad():
    phrase = recovery.generate_phrase()
    salt = b"s" * 16
    dek = vault.new_dek()
    wrapped = vault.wrap(dek, vault.derive_kek(recovery.phrase_to_entropy(phrase), salt))
    assert vault.unwrap(wrapped, vault.derive_kek(recovery.phrase_to_entropy(phrase), salt)) == dek
    with pytest.raises(vault.VaultError):
        vault.unwrap(wrapped, vault.derive_kek(recovery.phrase_to_entropy(recovery.generate_phrase()), salt))
    vc = vault.VaultCrypto("k1", dek)
    env = vc.seal(b"secret", "txn", "id1")
    assert vc.open(env, "txn", "id1") == b"secret"
    with pytest.raises(vault.VaultError):
        vc.open(env, "txn", "id2")  # record swap detected


def test_backup_round_trip():
    blob = vault.encrypt_backup(b'{"x":1}', "correct horse", n=2**10)
    assert vault.decrypt_backup(blob, "correct horse") == b'{"x":1}'
    with pytest.raises(vault.VaultError):
        vault.decrypt_backup(blob, "wrong")
    with pytest.raises(vault.VaultError):
        vault.decrypt_backup(blob[:-1] + bytes([blob[-1] ^ 1]), "correct horse")


def test_memory_keychain_off_ios():
    kc = keychain()
    assert kc.is_secure is False
    kc.set("a", b"1"); assert kc.get("a") == b"1"; kc.delete("a"); assert kc.get("a") is None
