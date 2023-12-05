import SwiftUI

extension View {
    @ViewBuilder
    @inlinable
    func transformIf<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
