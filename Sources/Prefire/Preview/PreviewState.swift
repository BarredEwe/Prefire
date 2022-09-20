//
//  PreviewState.swift
//  
//
//  Created by Maksim Grishutin on 04.08.2022.
//

import Foundation

public protocol PreviewState: CaseIterable { }

public enum DefaultState: PreviewState {
    case `default`
}
