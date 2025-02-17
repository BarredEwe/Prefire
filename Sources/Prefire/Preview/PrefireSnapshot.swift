import SwiftUI

#if canImport(XCTest)
public struct DeviceConfig {
    public var safeArea: UIEdgeInsets
    public var size: CGSize?
    public var traits: UITraitCollection
    
    public init(safeArea: UIEdgeInsets, size: CGSize? = nil, traits: UITraitCollection) {
        self.safeArea = safeArea
        self.size = size
        self.traits = traits
    }
}

@MainActor public struct PrefireSnapshot<Content: SwiftUI.View> {
    public var content: Content
    public var name: String
    public var isScreen: Bool
    public var device: DeviceConfig
    public var traits: UITraitCollection = .init()
    public var settings: PreferenceKeys?

    public init(_ preview: _Preview, testName: String = #function, device: DeviceConfig, settings: PreferenceKeys? = nil) where Content == AnyView {
        content = preview.content
        name = preview.displayName ?? testName
        isScreen = preview.layout == .device
        self.device = device
        self.settings = settings
    }

    public init(_ view: Content, name: String, isScreen: Bool, device: DeviceConfig, traits: UITraitCollection = .init(), settings: PreferenceKeys? = nil) {
        content = view
        self.name = name
        self.isScreen = isScreen
        self.device = device
        self.traits = traits
        self.settings = settings
    }

    public init(_ view: UIView, name: String, isScreen: Bool, device: DeviceConfig, traits: UITraitCollection = .init()) where Content == ViewRepresentable<UIView> {
        content = ViewRepresentable(view: view)
        self.name = name
        self.isScreen = isScreen
        self.device = device
        self.traits = traits
    }

    public init(_ viewController: UIViewController, name: String, isScreen: Bool, device: DeviceConfig, traits: UITraitCollection = .init()) where Content == ViewControllerRepresentable<UIViewController> {
        content = ViewControllerRepresentable(viewController: viewController)
        self.name = name
        self.isScreen = isScreen
        self.device = device
        self.traits = traits
    }
}
#endif
