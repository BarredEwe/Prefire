import SwiftUI

/// Preview model
///
/// Contains all information about Preview
public struct PreviewModel: Identifiable {
    /// Name of our Story/Flow.
    public typealias UserStory = String

    /// Preview state (just a `String`)
    public typealias State = String

    /// Layout type. Is nedded for understanding type of layout
    ///
    /// For example:
    /// `Button`, `TextField`, `Cell`  - component
    /// FullScreen `View` -  screen
    public enum LayoutType: Equatable {
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

    /// Layout type
    public var type: LayoutType

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
        id: String? = nil,
        content: @escaping () -> any View,
        name: String,
        type: LayoutType = .component,
        device: PreviewDevice?
    ) {
        self.id = id ?? name + String(describing: content.self)
        self.content = { AnyView(content()) }
        self.name = name
        self.type = type
        self.device = device
    }

    public init(
        id: String? = nil,
        content: @escaping () -> UIView,
        name: String,
        type: LayoutType = .component,
        device: PreviewDevice?
    ) {
        self.init(id: id, content: { AnyView(ViewRepresentable(view: content())) }, name: name, type: type, device: device)
    }

    public init(
        id: String? = nil,
        content: @escaping () -> UIViewController,
        name: String,
        type: LayoutType = .component,
        device: PreviewDevice?
    ) {
        self.init(id: id, content: { AnyView(ViewControllerRepresentable(viewController: content())) }, name: name, type: type, device: device)
    }
}
