//
//  File.swift
//  
//
//  Created by Maksim Grishutin on 08.08.2022.
//

import SwiftUI

public struct UserStoryPreferenceKey: PreferenceKey {
    public static var defaultValue: SystemView.UserStory?

    public static func reduce(value: inout SystemView.UserStory?, nextValue: () -> SystemView.UserStory?) {
        value = nextValue()
    }
}

public extension View {
    func userStory(_ userStory: SystemView.UserStory) -> some View {
        preference(key: UserStoryPreferenceKey.self, value: userStory)
    }

//    func onPreferenceUserStory(perform action: @escaping (SystemView.UserStory?) -> Void) -> some View {
//        onPreferenceChange(UserStoryPreferenceKey.self, perform: action)
//    func preferenceTintColor(_ color: Color?) -> some View {
//        preference(key: TintColorPreferenceKey.self, value: color)
//    }
//
//    func onPreferenceTintColorChange(perform action: @escaping (Color?) -> Void) -> some View {
//        onPreferenceChange(TintColorPreferenceKey.self, perform: action)
//    }
}
