import SwiftUI

#if os(iOS) || os(tvOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Canvas a snapshot is rendered on.
///
/// `PreviewModel` stores one, so the type is available whether or not XCTest can be imported.
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
    /// Backing scale factor used to render the snapshot.
    ///
    /// Fixed rather than taken from the current display, so the image size does not depend
    /// on the machine running the tests.
    public var scale: CGFloat

    public init(size: CGSize? = nil, scale: CGFloat = 2) {
        self.size = size
        self.scale = scale
    }
    #endif
}
