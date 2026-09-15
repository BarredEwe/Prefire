import Foundation
import SwiftUI

public extension View {
    /// Ignore `Prefire` processing this View for Playbook and Snapshots
    ///
    /// Prefire plugin will find this func and skip this View.
    /// Works only with `#Preview` macro
    ///
    /// - Returns: Self View
    @inlinable
    func prefireIgnored() -> some View {
        self
    }

    /// Include View for working with `Prefire` and generate Playbook and Snapshots
    /// - Returns: Self View
    @inlinable
    func prefireEnabled() -> some View {
        self
    }

    /// Replace this View with an opaque placeholder while a snapshot is rendered.
    ///
    /// Use it for content that changes between runs — dates, timers, remote images, random data:
    ///
    /// ```swift
    /// Text(Date.now.formatted()).snapshotMasked()
    /// ```
    ///
    /// The View is still laid out, so it keeps its size and nothing around it moves.
    /// Apply the modifier to a container to mask its whole subtree with a single placeholder.
    ///
    /// Outside of snapshots — Xcode Canvas, Playbook, the app itself — this is a no-op
    /// and the real content is shown.
    ///
    /// - Parameter color: Placeholder color. Opaque and appearance-independent by default.
    /// - Returns: Masked View
    func snapshotMasked(color: Color = .prefireSnapshotMask) -> some View {
        modifier(SnapshotMaskModifier(color: color))
    }
}

public extension Color {
    /// Default placeholder color of `snapshotMasked()`.
    ///
    /// A fixed sRGB gray rather than a system color, so it renders the same in any appearance.
    static let prefireSnapshotMask = Color(.sRGB, red: 0.5, green: 0.5, blue: 0.5, opacity: 1)
}

// MARK: - Private

/// Hides the content and draws an opaque placeholder in its place, keeping the original layout.
struct SnapshotMaskModifier: ViewModifier {
    @Environment(\.isPrefireSnapshotRendering) private var isSnapshotRendering

    let color: Color

    @ViewBuilder
    func body(content: Content) -> some View {
        if isSnapshotRendering {
            content
                .hidden()
                .overlay(color)
        } else {
            content
        }
    }
}

/// Turned on by `PrefireSnapshot` while it renders, so masking never reaches Canvas or Playbook.
struct PrefireSnapshotRenderingKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var isPrefireSnapshotRendering: Bool {
        get { self[PrefireSnapshotRenderingKey.self] }
        set { self[PrefireSnapshotRenderingKey.self] = newValue }
    }
}
