//
//  UIState.swift
//  
//
//  Created by Maksim Grishutin on 04.08.2022.
//

import Foundation

public protocol UIState: CaseIterable { }

public enum DefaultState: UIState {
    case `default`
}
