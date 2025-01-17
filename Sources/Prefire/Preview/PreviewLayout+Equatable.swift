import SwiftUI

extension PreviewLayout: @retroactive Equatable {
    public static func == (lhs: PreviewLayout, rhs: PreviewLayout) -> Bool {
        switch lhs {
        case .sizeThatFits:
            if case .sizeThatFits = rhs { return true }
        case .device:
            if case .device = rhs { return true }
        case let .fixed(lhsWidth, lhsHeight):
            if case let .fixed(rhsWidth, rhsHeight) = rhs {
                return lhsWidth == rhsWidth && lhsHeight == rhsHeight
            }
        default:
            return false
        }
        return false
    }
}
