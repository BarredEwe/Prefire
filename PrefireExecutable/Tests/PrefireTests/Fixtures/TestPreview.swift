import Foundation
import XCTest
import SwiftUI

let fixtureTestPreviewSource = #filePath

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

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
#Preview("Preview with properties") {
    @Previewable @State var foo: Bool = false
    Text("TestPreview_WithProperties")
}

#Preview
{
    VStack
    {
        Text("Preview formatted with Allman")
    }
}
