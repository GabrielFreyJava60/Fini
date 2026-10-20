"""iOS Keychain via rubicon-objc → Security.framework (SecItemAdd/CopyMatching/Delete).

UNVERIFIED ON DEVICE: written against the documented C API, exercised only through the
in-memory fallback on Linux. Off-iOS (briefcase dev, tests) an in-memory store is used and
`is_secure` is False so the UI can warn. Items use kSecAttrAccessibleWhenUnlockedThisDeviceOnly
(no iCloud Keychain sync — unlike the Swift version)."""
from __future__ import annotations

import sys

SERVICE = "com.gabrielfreidlin.finance.vault"


class KeychainError(Exception):
    pass


class _MemoryKeychain:
    is_secure = False

    def __init__(self):
        self._items: dict[str, bytes] = {}

    def set(self, account: str, data: bytes):
        self._items[account] = bytes(data)

    def get(self, account: str) -> bytes | None:
        return self._items.get(account)

    def delete(self, account: str):
        self._items.pop(account, None)


class _IOSKeychain:
    is_secure = True

    def __init__(self):
        from ctypes import POINTER, byref, c_int32, c_void_p, cdll
        from rubicon.objc import ObjCClass, ObjCInstance
        from rubicon.objc.runtime import load_library

        self._sec = load_library("Security")
        self._cf = cdll.LoadLibrary("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation")
        for fn in ("SecItemAdd", "SecItemCopyMatching", "SecItemDelete", "SecItemUpdate"):
            getattr(self._sec, fn).restype = c_int32
        self._sec.SecItemAdd.argtypes = [c_void_p, c_void_p]
        self._sec.SecItemCopyMatching.argtypes = [c_void_p, POINTER(c_void_p)]
        self._sec.SecItemDelete.argtypes = [c_void_p]
        self._sec.SecItemUpdate.argtypes = [c_void_p, c_void_p]
        self._byref, self._vp, self._Inst = byref, c_void_p, ObjCInstance
        self._NSDict = ObjCClass("NSMutableDictionary")
        self._NSData = ObjCClass("NSData")
        self._NSNumber = ObjCClass("NSNumber")

        def const(name):
            return ObjCInstance(c_void_p.in_dll(self._sec, name))

        self.k = {n: const(n) for n in (
            "kSecClass", "kSecClassGenericPassword", "kSecAttrService", "kSecAttrAccount", "kSecValueData",
            "kSecReturnData", "kSecMatchLimit", "kSecMatchLimitOne", "kSecAttrAccessible",
            "kSecAttrAccessibleWhenUnlockedThisDeviceOnly")}

    def _query(self, account):
        q = self._NSDict.alloc().init()
        q.setObject(self.k["kSecClassGenericPassword"], forKey=self.k["kSecClass"])
        q.setObject(SERVICE, forKey=self.k["kSecAttrService"])
        q.setObject(account, forKey=self.k["kSecAttrAccount"])
        return q

    def set(self, account, data: bytes):
        self.delete(account)
        q = self._query(account)
        q.setObject(self._NSData.dataWithBytes(data, length=len(data)), forKey=self.k["kSecValueData"])
        q.setObject(self.k["kSecAttrAccessibleWhenUnlockedThisDeviceOnly"], forKey=self.k["kSecAttrAccessible"])
        status = self._sec.SecItemAdd(q.ptr, None)
        if status != 0:
            raise KeychainError(f"SecItemAdd failed: OSStatus {status}")

    def get(self, account):
        q = self._query(account)
        q.setObject(self._NSNumber.numberWithBool(True), forKey=self.k["kSecReturnData"])
        q.setObject(self.k["kSecMatchLimitOne"], forKey=self.k["kSecMatchLimit"])
        out = self._vp()
        status = self._sec.SecItemCopyMatching(q.ptr, self._byref(out))
        if status == -25300:  # errSecItemNotFound
            return None
        if status != 0:
            raise KeychainError(f"SecItemCopyMatching failed: OSStatus {status}")
        data = self._Inst(out)
        import ctypes
        return ctypes.string_at(data.bytes, data.length)

    def delete(self, account):
        status = self._sec.SecItemDelete(self._query(account).ptr)
        if status not in (0, -25300):
            raise KeychainError(f"SecItemDelete failed: OSStatus {status}")


_instance = None


def keychain():
    global _instance
    if _instance is None:
        if sys.platform == "ios":
            # No silent fallback on device: losing the DEK would lose data.
            _instance = _IOSKeychain()
        else:
            _instance = _MemoryKeychain()
    return _instance
