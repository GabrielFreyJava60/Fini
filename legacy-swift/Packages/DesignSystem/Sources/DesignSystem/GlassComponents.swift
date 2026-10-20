import SwiftUI

/// L2 floating control: Liquid Glass quick-add button. Falls back to a solid fill
/// when Reduce Transparency is on.
public struct QuickAddButton: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let action: () -> Void
    @State private var taps = 0

    public init(action: @escaping () -> Void) { self.action = action }

    public var body: some View {
        Button {
            taps += 1
            action()
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .frame(width: 56, height: 56)
        }
        .buttonStyle(.plain)
        .modifier(GlassOrSolid(reduceTransparency: reduceTransparency))
        .sensoryFeedback(.impact(weight: .light), trigger: taps)
        .accessibilityLabel(Text("Add transaction"))
    }
}

struct GlassOrSolid: ViewModifier {
    let reduceTransparency: Bool
    func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(Circle().fill(.tint))
        } else {
            content.glassEffect(.regular.tint(.accentColor).interactive(), in: .circle)
        }
    }
}
