import SwiftUI

#if os(iOS) || os(tvOS)
import UIKit
public typealias PrefireSnapshotView = AnyView
#elseif os(macOS)
import AppKit
public typealias PrefireSnapshotView = NSView
#endif

#if canImport(XCTest)
public struct DeviceConfig {
    public var size: CGSize?

    #if os(iOS) || os(tvOS)
    public var safeArea: UIEdgeInsets
    public var traits: UITraitCollection

    public init(safeArea: UIEdgeInsets, size: CGSize? = nil, traits: UITraitCollection) {
        self.safeArea = safeArea
        self.size = size
        self.traits = traits
    }
    #elseif os(macOS)
    public init(size: CGSize) {
        self.size = size
    }
    #endif
}

@MainActor public struct PrefireSnapshot<Content: SwiftUI.View> {
    private var previewContent: Content
    public var name: String
    public var isScreen: Bool
    #if os(iOS) || os(tvOS)
    public var device: DeviceConfig
    #elseif os(macOS)
    public var device: DeviceConfig?
    #endif

    #if os(iOS) || os(tvOS)
    public var traits: UITraitCollection = .init()
    #endif

    private var content: AnyView {
        #if os(iOS) || os(tvOS)
        if isScreen {
            AnyView(previewContent)
        } else {
            AnyView(
                previewContent
                    .frame(width: device.size?.width)
                    .fixedSize(horizontal: false, vertical: true)
            )
        }
        #else
        AnyView(previewContent)
        #endif
    }

    #if os(iOS) || os(tvOS)
    public init(_ preview: _Preview, testName: String = #function, device: DeviceConfig) where Content == AnyView {
        previewContent = preview.content
        name = preview.displayName ?? testName
        isScreen = preview.layout == .device
        self.device = device
    }
    #elseif os(macOS)
    public init(_ preview: _Preview, testName: String = #function, device: DeviceConfig? = nil) where Content == AnyView {
        previewContent = preview.content
        name = preview.displayName ?? testName
        isScreen = false
        self.device = device
    }
    #endif

    #if os(iOS) || os(tvOS)
    public init(@ViewBuilder _ view: @escaping @MainActor () -> Content, name: String, isScreen: Bool, device: DeviceConfig, traits: UITraitCollection = .init()) {
        previewContent = view()
        self.name = name
        self.isScreen = isScreen
        self.device = device
        self.traits = traits
    }

    @_disfavoredOverload
    public init<T: UIView>(_ view: @escaping @MainActor () -> T, name: String, isScreen: Bool, device: DeviceConfig, traits: UITraitCollection = .init()) where Content == ViewRepresentable<T> {
        previewContent = ViewRepresentable(view: view())
        self.name = name
        self.isScreen = isScreen
        self.device = device
        self.traits = traits
    }

    @_disfavoredOverload
    public init<T: UIViewController>(_ viewController: @escaping @MainActor () -> T, name: String, isScreen: Bool, device: DeviceConfig, traits: UITraitCollection = .init()) where Content == ViewControllerRepresentable<T> {
        previewContent = ViewControllerRepresentable(viewController: viewController())
        self.name = name
        self.isScreen = isScreen
        self.device = device
        self.traits = traits
    }
    #elseif os(macOS)
    public init(@ViewBuilder _ view: @escaping @MainActor () -> Content, name: String, isScreen: Bool = false, device: DeviceConfig? = nil) {
        previewContent = view()
        self.name = name
        self.isScreen = isScreen
        self.device = device
    }

    @_disfavoredOverload
    public init<T: NSView>(_ view: @escaping @MainActor () -> T, name: String, isScreen: Bool = false, device: DeviceConfig? = nil) where Content == PrefireNSViewRepresentable<T> {
        previewContent = PrefireNSViewRepresentable(view: view())
        self.name = name
        self.isScreen = isScreen
        self.device = device
    }

    @_disfavoredOverload
    public init<T: NSViewController>(_ viewController: @escaping @MainActor () -> T, name: String, isScreen: Bool = false, device: DeviceConfig? = nil) where Content == PrefireNSViewControllerRepresentable<T> {
        previewContent = PrefireNSViewControllerRepresentable(viewController: viewController())
        self.name = name
        self.isScreen = isScreen
        self.device = device
    }
    #endif

    public func loadViewWithPreferences() -> (PrefireSnapshotView, PreferenceKeys) {
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

        return (render(view: view), preferences)
    }

    private func render(view: AnyView) -> PrefireSnapshotView {
        #if os(iOS) || os(tvOS)
        let hostingController = UIHostingController(rootView: view)
        let window = UIWindow(frame: .init())

        window.isHidden = false
        window.rootViewController = hostingController

        hostingController.view.setNeedsLayout()
        hostingController.view.layoutIfNeeded()
        return view
        #elseif os(macOS)
        let hostingController = NSHostingController(rootView: view)
        let hostingView = hostingController.view
        let size = device?.size ?? hostingView.fittingSize
        hostingView.frame = CGRect(origin: .zero, size: size)
        hostingView.layoutSubtreeIfNeeded()
        return hostingView
        #endif
    }
}
#endif
