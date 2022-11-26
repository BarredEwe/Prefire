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
    /// Name of our Story/Flow.
    public typealias UserStory = String

    /// Preview state (just a `String`)
    public typealias State = String

    /// View type. Is nedded for understanding type of layout
    ///
    /// For example:
    /// `Button`, `TextField`, `Cell`  - component
    /// FullScreen `View` -  screen
    public enum ViewType: Equatable {
        case screen
        case component
    }

    /// Preview identificator
    public let id: String

    /// Static preview (type erased) view
    public let content: () -> AnyView

    /// Preview name
    public let name: String

    /// Preview state (just a `String`)
    ///
    /// Example:
    ///
    ///     (.default, loading etc.)
    public var state: State?

    /// View type
    public var type: ViewType

    /// Device for showing preview
    public var device: PreviewDevice?

    /// Name of our Story/Flow.
    ///
    /// Needed to combine multiple views into one Story/Flow
    public var story: UserStory?

    /// Render time
    ///
    /// The time from when a view was created (`.init`) to when it was shown (`.onAppear`)
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
