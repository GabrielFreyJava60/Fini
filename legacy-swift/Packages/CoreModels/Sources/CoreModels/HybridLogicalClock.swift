import Foundation

/// Hybrid Logical Clock timestamp used for per-field last-writer-wins merges.
/// Encoded as a lexicographically sortable string: "<millis:15>-<counter:6>-<node>".
public struct HLCTimestamp: Hashable, Codable, Sendable, Comparable, CustomStringConvertible {
    public var millis: Int64
    public var counter: UInt32
    public var node: String

    public init(millis: Int64, counter: UInt32, node: String) {
        self.millis = millis
        self.counter = counter
        self.node = node
    }

    public static func < (l: HLCTimestamp, r: HLCTimestamp) -> Bool {
        (l.millis, l.counter, l.node) < (r.millis, r.counter, r.node)
    }

    public var description: String {
        let m = String(millis).leftPadded(to: 15)
        let c = String(counter).leftPadded(to: 6)
        return "\(m)-\(c)-\(node)"
    }

    public init?(_ encoded: String) {
        let parts = encoded.split(separator: "-", maxSplits: 2).map(String.init)
        guard parts.count == 3, let m = Int64(parts[0]), let c = UInt32(parts[1]) else { return nil }
        self.init(millis: m, counter: c, node: parts[2])
    }
}

/// Thread-safe HLC generator. One per device.
public actor HybridLogicalClock {
    private var last: HLCTimestamp
    private let now: @Sendable () -> Int64

    public init(node: String, now: @escaping @Sendable () -> Int64 = { Int64(Date().timeIntervalSince1970 * 1000) }) {
        self.now = now
        self.last = HLCTimestamp(millis: 0, counter: 0, node: node)
    }

    /// Timestamp for a local event.
    public func tick() -> HLCTimestamp {
        let wall = now()
        if wall > last.millis {
            last = HLCTimestamp(millis: wall, counter: 0, node: last.node)
        } else {
            last = HLCTimestamp(millis: last.millis, counter: last.counter + 1, node: last.node)
        }
        return last
    }

    /// Merge a remote timestamp (on receiving a synced record).
    public func receive(_ remote: HLCTimestamp) -> HLCTimestamp {
        let wall = now()
        let maxMillis = max(wall, last.millis, remote.millis)
        let counter: UInt32
        if maxMillis == last.millis && maxMillis == remote.millis {
            counter = max(last.counter, remote.counter) + 1
        } else if maxMillis == last.millis {
            counter = last.counter + 1
        } else if maxMillis == remote.millis {
            counter = remote.counter + 1
        } else {
            counter = 0
        }
        last = HLCTimestamp(millis: maxMillis, counter: counter, node: last.node)
        return last
    }
}

extension String {
    fileprivate func leftPadded(to width: Int) -> String {
        count >= width ? self : String(repeating: "0", count: width - count) + self
    }
}
