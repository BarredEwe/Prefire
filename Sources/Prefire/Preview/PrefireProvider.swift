//
//  PrefireProvider.swift
//  
//
//  Created by Maksim Grishutin on 04.08.2022.
//

import SwiftUI

/// -----
/// Ограничение: в preview должно быть только одно состояние View
public protocol PrefireProvider: PreviewProvider {
    associatedtype State: PreviewState

    static var state: State { get set }
}

public extension PrefireProvider {
    static var state: DefaultState {
        get { .default }
        set { }
    }
}
