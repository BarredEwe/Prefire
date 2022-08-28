// Generated using Sourcery 1.8.2 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT

// swiftlint:disable all

import SwiftUI
import PreFire

@testable import SnapshotAppSwiftUI

public enum PreviewModels {
    public static var models: [PreviewModel] = {
        var views: [PreviewModel] = []


        return views.sorted(by: { $0.name > $1.name || $0.story ?? "" > $1.story ?? "" })
    }()
}

extension PreviewLayout: Equatable {
    public static func == (lhs: PreviewLayout, rhs: PreviewLayout) -> Bool {
        switch lhs {
        case .sizeThatFits:
            if case .sizeThatFits = rhs { return true }
        case .device:
            if case .device = rhs { return true }
        default: return false
        }
        return false
    }
}
