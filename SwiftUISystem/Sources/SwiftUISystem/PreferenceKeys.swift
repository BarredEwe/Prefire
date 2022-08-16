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
    func userStory(_ userStory: PreviewModel.UserStory) -> some View {
        preference(key: UserStoryPreferenceKey.self, value: userStory)
    }
}

public struct ViewTypePreferenceKey: PreferenceKey {
    public static var defaultValue: PreviewModel.ViewType = .component

    public static func reduce(value: inout PreviewModel.ViewType, nextValue: () -> PreviewModel.ViewType) {
        value = nextValue()
    }
}

public extension View {
    func viewType(_ viewType: PreviewModel.ViewType) -> some View {
        preference(key: ViewTypePreferenceKey.self, value: viewType)
    }
}
