import SwiftUI

#if os(iOS) || os(tvOS)
import UIKit
#endif

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

/// What Prefire waits for before it captures a snapshot, set by `snapshot(waitForIdle:timeout:)`
/// and `snapshot(waitUntil:timeout:)`.
public enum SnapshotWait: @unchecked Sendable {
    /// Renders until the frame stops changing.
    case idle(timeout: TimeInterval?)

    /// Renders until every condition returns `true`.
    case conditions([SnapshotWaitCondition], timeout: TimeInterval?)

    /// Captures right away, ignoring `SnapshotWaitDefaults.waitForIdle`.
    case disabled

    /// Combines the waits of several views of one preview: a condition is waited for over idle, idle
    /// over an opt-out, every condition has to be met, and the longest timeout applies.
    func combined(with other: SnapshotWait) -> SnapshotWait {
        switch (self, other) {
        case let (.conditions(lhs, lhsTimeout), .conditions(rhs, rhsTimeout)):
            .conditions(lhs + rhs, timeout: Self.longest(lhsTimeout, rhsTimeout))
        case (.conditions, _), (.idle, .disabled):
            self
        case (_, .conditions), (.disabled, .idle):
            other
        case let (.idle(lhsTimeout), .idle(rhsTimeout)):
            .idle(timeout: Self.longest(lhsTimeout, rhsTimeout))
        case (.disabled, .disabled):
            .disabled
        }
    }

    private static func longest(_ lhs: TimeInterval?, _ rhs: TimeInterval?) -> TimeInterval? {
        guard let lhs, let rhs else { return lhs ?? rhs }
        return max(lhs, rhs)
    }
}

extension SnapshotWait: Equatable {
    /// Conditions are never equal, so a re-rendered preview always hands over its latest closure.
    public static func == (lhs: SnapshotWait, rhs: SnapshotWait) -> Bool {
        switch (lhs, rhs) {
        case let (.idle(lhsTimeout), .idle(rhsTimeout)): lhsTimeout == rhsTimeout
        case (.disabled, .disabled): true
        default: false
        }
    }
}

/// A condition of `snapshot(waitUntil:timeout:)`.
public struct SnapshotWaitCondition: @unchecked Sendable {
    /// Call site of the modifier, named when the condition is not met in time.
    public let location: String

    let isMet: @MainActor () -> Bool

    public init(location: String, isMet: @escaping @MainActor () -> Bool) {
        self.location = location
        self.isMet = isMet
    }
}

/// How previews wait when they do not say so themselves: `snapshot_wait_for_idle` and
/// `snapshot_wait_timeout` of `.prefire.yml`, which the generated tests pass on.
public struct SnapshotWaitDefaults: Sendable {
    /// Wait for the frame to stop changing even when a preview does not ask for it.
    public var waitForIdle: Bool

    /// Time limit of a wait that does not set its own, in seconds.
    public var timeout: TimeInterval

    public init(waitForIdle: Bool = false, timeout: TimeInterval = 5) {
        self.waitForIdle = waitForIdle
        self.timeout = timeout
    }
}

/// How waiting for a preview ended.
public enum SnapshotWaitResult {
    #if os(iOS) || os(tvOS)
    /// The preview settled, captured where it was waited on.
    ///
    /// Compare this image instead of snapshotting the view again: a snapshot strategy hosts the view
    /// in a window of its own, and moving a preview to another window restarts its `.onAppear` and
    /// `.task`, so the state it reached while waiting would be lost.
    case settled(UIImage)
    #else
    /// The preview settled. The returned view shows that state and has spent `delay` already.
    case settled
    #endif

    /// The preview was not ready in time. The message says why, for the test to fail with.
    case timedOut(String)
}

public struct WaitPreferenceKey: PreferenceKey {
    public static let defaultValue: SnapshotWait? = nil

    public static func reduce(value: inout SnapshotWait?, nextValue: () -> SnapshotWait?) {
        guard let next = nextValue() else { return }
        value = value?.combined(with: next) ?? next
    }
}

/// Wrapper for secure data storage
public class PreferenceKeys: @unchecked Sendable {
    public var delay: TimeInterval
    public var precision: Float
    public var perceptualPrecision: Float
    public var record: Bool

    /// How waiting for the preview ended, or `nil` when it was not waited for.
    public internal(set) var waitResult: SnapshotWaitResult?

    /// What the preview asked to wait for.
    var wait: SnapshotWait?

    /// `previewUserStory(_:)` of the preview.
    public internal(set) var userStory: PreviewModel.UserStory?

    /// `previewState(_:)` of the preview.
    public internal(set) var state: PreviewModel.State?

    public init(delay: TimeInterval = 0, precision: Float = 1, perceptualPrecision: Float = 1, record: Bool = false) {
        self.delay = delay
        self.precision = precision
        self.perceptualPrecision = perceptualPrecision
        self.record = record
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
    /// Prefire renders the preview and compares frames: the snapshot is taken once nothing changed
    /// for about a third of a second. Combine it with
    /// `snapshot(delay:precision:perceptualPrecision:record:)` when you also need to tune the
    /// comparison, or to keep a floor under the wait: `delay` is spent before the frames are
    /// compared, so a preview that only starts working after it is still waited for.
    ///
    /// - Parameters:
    ///   - waitForIdle: Whether to wait for the rendered frame to stabilize. `false` also opts the
    ///                  preview out of the `snapshot_wait_for_idle` configuration key.
    ///   - timeout: How long to wait before the test fails, counted once `delay` is spent. `nil` uses
    ///              `snapshot_wait_timeout` from the configuration, 5 seconds unless set.
    @inlinable
    func snapshot(waitForIdle: Bool, timeout: TimeInterval? = nil) -> some View {
        preference(key: WaitPreferenceKey.self, value: waitForIdle ? .idle(timeout: timeout) : .disabled)
    }

    /// Use this modifier when the preview is ready at a moment only it knows about,
    /// like a loaded view model or a finished animation.
    ///
    /// The condition is checked on the main thread while the preview keeps rendering. When several
    /// views of a preview set one, all of them have to be met. A condition is waited for over
    /// `snapshot(waitForIdle:timeout:)`.
    ///
    /// - Parameters:
    ///   - condition: Returns `true` once the preview is ready to be captured.
    ///   - timeout: How long to wait before the test fails, counted once `delay` is spent. `nil` uses
    ///              `snapshot_wait_timeout` from the configuration, 5 seconds unless set.
    ///   - fileID: File of the call site, named when the condition is not met in time.
    ///   - line: Line of the call site, named when the condition is not met in time. A helper that
    ///           wraps this modifier can take `fileID` and `line` with the same defaults and pass
    ///           them on, so the message names the preview using the helper rather than the helper.
    @inlinable
    func snapshot(
        waitUntil condition: @escaping @MainActor () -> Bool,
        timeout: TimeInterval? = nil,
        fileID: String = #fileID,
        line: UInt = #line
    ) -> some View {
        preference(
            key: WaitPreferenceKey.self,
            value: .conditions([SnapshotWaitCondition(location: "\(fileID):\(line)", isMet: condition)], timeout: timeout)
        )
    }
}
