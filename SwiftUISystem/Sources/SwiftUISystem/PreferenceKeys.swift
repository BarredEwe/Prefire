//
//  File.swift
//  
//
//  Created by Maksim Grishutin on 08.08.2022.
//

import SwiftUI

public struct UserStoryPreferenceKey: PreferenceKey {
    public static var defaultValue: SystemViewModel.UserStory?

    public static func reduce(value: inout SystemViewModel.UserStory?, nextValue: () -> SystemViewModel.UserStory?) {
        value = nextValue()
    }
}

public extension View {
    func userStory(_ userStory: SystemViewModel.UserStory) -> some View {
        preference(key: UserStoryPreferenceKey.self, value: userStory)
    }
}

public struct ViewTypePreferenceKey: PreferenceKey {
    public static var defaultValue: SystemViewModel.ViewType = .component

    public static func reduce(value: inout SystemViewModel.ViewType, nextValue: () -> SystemViewModel.ViewType) {
        value = nextValue()
    }
}

public extension View {
    func viewType(_ viewType: SystemViewModel.ViewType) -> some View {
        preference(key: ViewTypePreferenceKey.self, value: viewType)
    }
}
