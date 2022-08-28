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
}

public extension UISystemProvider {
    static var state: DefaultState {
        get { .default }
        set { }
    }
}
