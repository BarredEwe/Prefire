//
//  UISystemProvider.swift
//  
//
//  Created by Maksim Grishutin on 04.08.2022.
//

import SwiftUI

/// -----
/// Ограничение: в preview должно быть только одно состояние View
public protocol UISystemProvider: PreviewProvider {
    associatedtype State: UIState

    static var state: State { get set }
    static var viewType: SystemView.ViewType { get }
    static var story: SystemView.UserStory? { get }
}

public extension UISystemProvider {
    static var state: DefaultState {
        get { .default }
        set { }
    }

    static var viewType: SystemView.ViewType {
        .screen
    }
    static var story: SystemView.UserStory? {
        nil
    }
}
