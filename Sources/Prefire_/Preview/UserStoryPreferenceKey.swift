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
