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
    private var previewContent: Content
    public var name: String
    public var isScreen: Bool
    public var device: DeviceConfig
    public var traits: UITraitCollection = .init()
    
    private var content: AnyView {
        if isScreen {
            AnyView(previewContent)
        } else {
            AnyView(
                previewContent
                    .frame(width: device.size?.width)
                    .fixedSize(horizontal: false, vertical: true)
            )
        }
    }

    public init(_ preview: _Preview, testName: String = #function, device: DeviceConfig) where Content == AnyView {
        previewContent = preview.content
        name = preview.displayName ?? testName
        isScreen = preview.layout == .device
        self.device = device
    }

    public init(_ view: Content, name: String, isScreen: Bool, device: DeviceConfig, traits: UITraitCollection = .init()) {
        previewContent = view
        self.name = name
        self.isScreen = isScreen
        self.device = device
        self.traits = traits
    }

    public init(_ view: UIView, name: String, isScreen: Bool, device: DeviceConfig, traits: UITraitCollection = .init()) where Content == ViewRepresentable<UIView> {
        previewContent = ViewRepresentable(view: view)
        self.name = name
        self.isScreen = isScreen
        self.device = device
        self.traits = traits
    }

    public init(_ viewController: UIViewController, name: String, isScreen: Bool, device: DeviceConfig, traits: UITraitCollection = .init()) where Content == ViewControllerRepresentable<UIViewController> {
        previewContent = ViewControllerRepresentable(viewController: viewController)
        self.name = name
        self.isScreen = isScreen
        self.device = device
        self.traits = traits
    }
    
    public func loadViewWithPreferences() -> (AnyView, PreferenceKeys) {
        let preferences = PreferenceKeys()
        
        let view = AnyView(
            content
                .onPreferenceChange(DelayPreferenceKey.self) {
                    preferences.delay = $0
                }
                .onPreferenceChange(PrecisionPreferenceKey.self) {
                    preferences.precision = $0
                }
                .onPreferenceChange(PerceptualPrecisionPreferenceKey.self) {
                    preferences.perceptualPrecision = $0
                }
                .onPreferenceChange(RecordPreferenceKey.self) {
                    preferences.record = $0
                }
        )

        // In order to call onPreferenceChange, render the view once
        render(view: view)

        return (view, preferences)
    }
    
    // MARK: - Private functions
    
    private func render(view: AnyView) {
        #if os(iOS)
        let hostingController = UIHostingController(rootView: view)
        let window = UIWindow(frame: .init())
        
        window.isHidden = false
        window.rootViewController = hostingController
        
        hostingController.view.setNeedsLayout()
        hostingController.view.layoutIfNeeded()
        #else
        let hostingController = NSHostingController(rootView: view)
        let window = NSWindow(
            contentRect: .init(),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        window.contentView = hostingController.view
        window.isReleasedWhenClosed = false        
        #endif
    }
}
#endif
