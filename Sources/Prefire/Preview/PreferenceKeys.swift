//
//  PreferenceKeys.swift
//  
//
//  Created by Maksim Grishutin on 08.08.2022.
//

import SwiftUI

public struct UserStoryPreferenceKey: PreferenceKey {
    public static var defaultValue: PreviewModel.UserStory?

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
    public static var defaultValue: PreviewModel.State?

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
     public static var defaultValue: TimeInterval = 0.0

     public static func reduce(value: inout TimeInterval, nextValue: () -> TimeInterval) {
         value = nextValue()
     }
 }

 public struct PrecisionPreferenceKey: PreferenceKey {
     public static var defaultValue: Float = 1.0

     public static func reduce(value: inout Float, nextValue: () -> Float) {
         value = nextValue()
     }
 }

 public extension View {
     /// Use this modifier when you want to apply snapshot-specific preferences,
     /// like delay and precision, to the view.
     /// These preferences can then be retrieved and used elsewhere in your view hierarchy.
     ///
     /// - Parameters:
     ///   - delay: The delay time in seconds that you want to set as a preference to the View.
     ///   - precision: The precision value that you want to set as a preference to the View.
     @inlinable
     func snapshot(delay: TimeInterval = .zero, precision: Float = 1.0) -> some View {
         self
             .preference(key: DelayPreferenceKey.self, value: delay)
             .preference(key: PrecisionPreferenceKey.self, value: precision)
     }
 }
