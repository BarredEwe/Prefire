import SwiftUI

public struct UserStoryPreferenceKey: PreferenceKey {
    public static let defaultValue: PreviewModel.UserStory? = nil

    public static func reduce(value: inout PreviewModel.UserStory?, nextValue: () -> PreviewModel.UserStory?) {
        value = nextValue()
    }
}

public extension View {
    /// Setting name of our Story/Flow.
    ///
    /// Needed to combine multiple views into one Story/Flow
    /// - Parameter userStory: Name of our Story/Flow
    @inlinable
    func previewUserStory(_ userStory: PreviewModel.UserStory) -> some View {
        preference(key: UserStoryPreferenceKey.self, value: userStory)
    }
}

// MARK: - State

public struct StatePreferenceKey: PreferenceKey {
    public static let defaultValue: PreviewModel.State? = nil

    public static func reduce(value: inout PreviewModel.State?, nextValue: () -> PreviewModel.State?) {
        value = nextValue()
    }
}

public extension View {
    /// Setting preview state
    ///
    /// Needed to set different preview state names
    /// - Parameter state: Preview state
    @inlinable
    func previewState(_ state: PreviewModel.State) -> some View {
        preference(key: StatePreferenceKey.self, value: state)
    }
}

// MARK: - Snapshot Attributes

public struct DelayPreferenceKey: PreferenceKey {
    public static let defaultValue: TimeInterval = 0.0

    public static func reduce(value: inout TimeInterval, nextValue: () -> TimeInterval) {
        value = nextValue()
    }
}

public struct PrecisionPreferenceKey: PreferenceKey {
    public static let defaultValue: Float = 1.0

    public static func reduce(value: inout Float, nextValue: () -> Float) {
        value = nextValue()
    }
}

public struct PerceptualPrecisionPreferenceKey: PreferenceKey {
    public static let defaultValue: Float = 1.0

    public static func reduce(value: inout Float, nextValue: () -> Float) {
        value = nextValue()
    }
}

public struct RecordPreferenceKey: PreferenceKey {
    public static let defaultValue: Bool = false

    public static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = nextValue()
    }
}

// MARK: - Waiting

/// Condition Prefire waits for before it captures a snapshot.
public enum SnapshotWait: @unchecked Sendable {
    /// Renders until the same frame comes back twice in a row.
    case idle

    /// Renders until `condition` returns `true`.
    ///
    /// - Parameter id: Call site of the modifier. Keeps the preference equal across re-renders.
    case condition(id: String, condition: @MainActor () -> Bool)

    /// Captures right away, ignoring `SnapshotWaitDefaults.waitForIdle`.
    case disabled
}

extension SnapshotWait: Equatable {
    public static func == (lhs: SnapshotWait, rhs: SnapshotWait) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.disabled, .disabled): true
        case let (.condition(lhsID, _), .condition(rhsID, _)): lhsID == rhsID
        default: false
        }
    }
}

/// Project wide waiting defaults, set by the generated tests from `.prefire.yml`.
///
/// Only read while snapshots are taken, so mutating them from `setUp()` is safe.
public enum SnapshotWaitDefaults {
    /// Wait for the frame to stabilize even when a preview does not ask for it.
    public nonisolated(unsafe) static var waitForIdle: Bool = false

    /// Time limit for a wait that does not set its own.
    public nonisolated(unsafe) static var timeout: TimeInterval = 5
}

public struct WaitPreferenceKey: PreferenceKey {
    public static let defaultValue: SnapshotWait? = nil

    public static func reduce(value: inout SnapshotWait?, nextValue: () -> SnapshotWait?) {
        value = nextValue()
    }
}

public struct WaitTimeoutPreferenceKey: PreferenceKey {
    /// `0` means "not set": the wait falls back to `SnapshotWaitDefaults.timeout`.
    public static let defaultValue: TimeInterval = 0

    public static func reduce(value: inout TimeInterval, nextValue: () -> TimeInterval) {
        value = nextValue()
    }
}

/// Wrapper for secure data storage
public class PreferenceKeys: @unchecked Sendable {
    public var delay: TimeInterval
    public var precision: Float
    public var perceptualPrecision: Float
    public var record: Bool

    /// Condition to wait for. `nil` falls back to `SnapshotWaitDefaults.waitForIdle`.
    public var wait: SnapshotWait?

    /// Time limit for `wait`. `0` falls back to `SnapshotWaitDefaults.timeout`.
    public var waitTimeout: TimeInterval

    /// Time the preview needed to become ready.
    ///
    /// Filled in on iOS/tvOS only: there the snapshot strategy renders its own copy of the view,
    /// so the wait runs on a probe and its duration is replayed as a delay. On macOS the view
    /// Prefire waited on is the one being captured, so no delay is needed.
    public internal(set) var settleDelay: TimeInterval = 0

    /// Why waiting failed, or `nil` when there was nothing to wait for or the wait succeeded.
    public internal(set) var waitFailure: String?

    /// Delay for the snapshot strategy: the explicit `delay`, or the measured `settleDelay`.
    public var resolvedDelay: TimeInterval { max(delay, settleDelay) }

    /// Condition to wait for, including the project wide default.
    public var resolvedWait: SnapshotWait? {
        switch wait {
        case nil: SnapshotWaitDefaults.waitForIdle ? .idle : nil
        case .some(.disabled): nil
        case let .some(wait): wait
        }
    }

    /// Time limit for `resolvedWait`, including the project wide default.
    public var resolvedTimeout: TimeInterval { waitTimeout > 0 ? waitTimeout : SnapshotWaitDefaults.timeout }

    public init(
        delay: TimeInterval = 0,
        precision: Float = 1,
        perceptualPrecision: Float = 1,
        record: Bool = false,
        wait: SnapshotWait? = nil,
        waitTimeout: TimeInterval = 0
    ) {
        self.delay = delay
        self.precision = precision
        self.perceptualPrecision = perceptualPrecision
        self.record = record
        self.wait = wait
        self.waitTimeout = waitTimeout
    }
}

public extension View {
    /// Use this modifier when you want to apply snapshot-specific preferences,
    /// like delay and precision, to the view.
    /// These preferences can then be retrieved and used elsewhere in your view hierarchy.
    ///
    /// - Parameters:
    ///   - delay: The delay time in seconds that you want to set as a preference to the View.
    ///   - precision: The percentage of pixels that must match.
    ///   - perceptualPrecision: The percentage a pixel must match the source pixel to be considered a match. 98-99% mimics the precision of the human eye.
    ///   - record: Whether or not to override the existing snapshot and record a new one.
    @inlinable
    func snapshot(delay: TimeInterval = .zero, precision: Float = 1.0, perceptualPrecision: Float = 1.0, record: Bool = false) -> some View {
        preference(key: DelayPreferenceKey.self, value: delay)
            .preference(key: PrecisionPreferenceKey.self, value: precision)
            .preference(key: PerceptualPrecisionPreferenceKey.self, value: perceptualPrecision)
            .preference(key: RecordPreferenceKey.self, value: record)
    }

    /// Use this modifier to capture the snapshot as soon as the preview stops changing,
    /// instead of guessing a fixed `delay`.
    ///
    /// Prefire renders the preview and compares consecutive frames: the snapshot is taken once the
    /// same frame comes back twice in a row. Combine it with
    /// `snapshot(delay:precision:perceptualPrecision:record:)` when you also need to tune the
    /// comparison, or to keep a floor under the wait.
    ///
    /// - Parameters:
    ///   - waitForIdle: Whether to wait for the rendered frame to stabilize. `false` also opts the
    ///                  preview out of the `snapshot_wait_for_idle` configuration key.
    ///   - timeout: How long to wait before the test fails.
    @inlinable
    func snapshot(waitForIdle: Bool, timeout: TimeInterval = SnapshotWaitDefaults.timeout) -> some View {
        preference(key: WaitPreferenceKey.self, value: waitForIdle ? .idle : .disabled)
            .preference(key: WaitTimeoutPreferenceKey.self, value: timeout)
    }

    /// Use this modifier when the preview is ready at a moment only it knows about,
    /// like a loaded view model or a finished animation.
    ///
    /// The condition is checked on the main thread while the preview keeps rendering.
    ///
    /// - Parameters:
    ///   - condition: Returns `true` once the preview is ready to be captured.
    ///   - timeout: How long to wait before the test fails.
    @inlinable
    func snapshotWait(
        until condition: @escaping @MainActor () -> Bool,
        timeout: TimeInterval = SnapshotWaitDefaults.timeout,
        fileID: String = #fileID,
        line: UInt = #line
    ) -> some View {
        preference(key: WaitPreferenceKey.self, value: .condition(id: "\(fileID):\(line)", condition: condition))
            .preference(key: WaitTimeoutPreferenceKey.self, value: timeout)
    }
}
