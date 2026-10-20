import SwiftUI
import WidgetKit
import CoreModels
import DesignSystem

public struct SafeToSpendEntry: TimelineEntry, Sendable {
    public let date: Date
    public let snapshot: WidgetSnapshot
}

public struct SafeToSpendProvider: TimelineProvider {
    public init() {}
    public func placeholder(in context: Context) -> SafeToSpendEntry { .init(date: .now, snapshot: .placeholder) }
    public func getSnapshot(in context: Context, completion: @escaping (SafeToSpendEntry) -> Void) {
        completion(.init(date: .now, snapshot: SnapshotStore.read()))
    }
    public func getTimeline(in context: Context, completion: @escaping (Timeline<SafeToSpendEntry>) -> Void) {
        let entry = SafeToSpendEntry(date: .now, snapshot: SnapshotStore.read())
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(30 * 60))))
    }
}

public struct SafeToSpendView: View {
    let entry: SafeToSpendEntry
    public init(entry: SafeToSpendEntry) { self.entry = entry }
    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Safe to spend").font(.caption).foregroundStyle(.secondary)
            MoneyText(entry.snapshot.safeToSpendToday)
                .widgetAccentable()
            if let fsi = entry.snapshot.stressIndex {
                Gauge(value: Double(fsi), in: 0...100) { Text("Pulse") }
                    .gaugeStyle(.accessoryLinearCapacity)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

/// Bundled by App/QuickLogWidgetExtension's @main WidgetBundle.
public struct SafeToSpendWidget: Widget {
    public init() {}
    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SafeToSpend", provider: SafeToSpendProvider()) { SafeToSpendView(entry: $0) }
            .configurationDisplayName("Safe to spend")
            .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline, .accessoryCircular])
    }
}
