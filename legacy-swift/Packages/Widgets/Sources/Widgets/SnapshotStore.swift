import Foundation
import CoreModels

/// Read-only minimal snapshot in the App Group (never the ledger). Written by the app after
/// each Runway/Pulse recompute; read by the widget timeline provider.
public enum SnapshotStore {
    public static let appGroupID = "group.com.gabrielfreidlin.finance"
    static var url: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("widget-snapshot.json")
    }

    public static func write(_ snapshot: WidgetSnapshot) throws {
        guard let url else { return }
        try JSONEncoder().encode(snapshot).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    public static func read() -> WidgetSnapshot {
        guard let url, let data = try? Data(contentsOf: url),
              let snap = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else { return .placeholder }
        return snap
    }
}
