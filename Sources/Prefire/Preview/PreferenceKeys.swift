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

/// Wrapper for secure data storage
public class PreferenceKeys: @unchecked Sendable {
    public var delay: TimeInterval
    public var precision: Float
    public var perceptualPrecision: Float
    public var record: Bool

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
}
