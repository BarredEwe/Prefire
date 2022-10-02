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
    @inlinable
    func previewUserStory(_ userStory: PreviewModel.UserStory) -> some View {
        preference(key: UserStoryPreferenceKey.self, value: userStory)
    }
}

// MARK: State

public struct StatePreferenceKey: PreferenceKey {
    public static var defaultValue: PreviewModel.State?

    public static func reduce(value: inout PreviewModel.State?, nextValue: () -> PreviewModel.State?) {
        value = nextValue()
    }
}

public extension View {
    @inlinable
    func previewState(_ state: PreviewModel.State) -> some View {
        preference(key: StatePreferenceKey.self, value: state)
    }
}
