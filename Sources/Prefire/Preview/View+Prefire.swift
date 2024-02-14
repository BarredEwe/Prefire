import Foundation
import SwiftUI

public extension View {
    /// Ignore `Prefire` processing this View for Playbook and Snapshots
    ///
    /// Prefire plugin will find this func and skip this View.
    /// Works only with `#Preview` macro
    ///
    /// - Returns: Self View
    @inlinable
    func prefireIgnored() -> some View {
        self
    }

    /// Include View for working with `Prefire` and generate Playbook and Snapshots
    /// - Returns: Self View
    @inlinable
    func prefireEnabled() -> some View {
        self
    }
}
