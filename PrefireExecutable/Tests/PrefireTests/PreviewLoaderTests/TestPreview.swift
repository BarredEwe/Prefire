import Foundation
@testable import prefire
import XCTest

import SwiftUI

#Preview {
    Text("TestPreview")
}

#Preview {
    Text("TestPreview_Prefire")
        .prefireEnabled()
}

#Preview {
    Text("TestPreview_Ignored")
        .prefireIgnored()
}
