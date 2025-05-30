import SwiftUI

#if os(macOS)
import AppKit

public typealias UIView = NSView
public typealias UIViewController = NSViewController
public typealias UIScreen = NSScreen
public typealias UIEdgeInsets = NSEdgeInsets
public typealias UIWindow = NSWindow

// Create a dummy trait collection type for macOS
public struct UITraitCollection {
    let displayScale: CGFloat
    public init(displayScale: CGFloat = 2.0) {
        self.displayScale = displayScale
    }
}

extension NSScreen? {
    var bounds: CGRect {
        return CGRect(x: 0, y: 0, width: 1024, height: 768)
    }
}

public extension NSEdgeInsets {
    static let zero = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
}
#endif
