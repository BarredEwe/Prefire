//
//  SystemViewModel.swift
//  
//
//  Created by Maksim Grishutin on 05.08.2022.
//

import SwiftUI

/// Preview model
///
/// Contains all information about Preview
public struct PreviewModel: Identifiable {
    public typealias UserStory = String
    public typealias State = String

    public enum ViewType: Equatable {
        case screen
        case component
    }
    
    public let id: String
    /// Наша statc view от Preview
    public let content: () -> AnyView
    /// Имя preview
    public let name: String
    /// Состояние preview (.default, loading и тд)
    public var state: State?
    /// Тип preview
    public var type: ViewType
    /// Устройство для отображения preview
    public var device: PreviewDevice?
    /// Наименование нашего Flow
    public var story: UserStory?
    /// Время рендеринга
    public var renderTime: String?

    public init(
        id: String,
        content: @escaping () -> AnyView,
        name: String,
        type: ViewType = .component,
        device: PreviewDevice?
    ) {
        self.id = id
        self.content = content
        self.name = name
        self.type = type
        self.device = device
    }
}
