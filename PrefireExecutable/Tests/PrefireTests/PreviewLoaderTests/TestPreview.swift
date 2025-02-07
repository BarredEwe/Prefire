import Foundation
@testable import prefire
import XCTest

import SwiftUI

#if swift(>=5.9)
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
#endif
