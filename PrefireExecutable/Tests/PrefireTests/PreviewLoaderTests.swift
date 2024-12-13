import Foundation
@testable import prefire
import XCTest

class PreviewLoaderTests: XCTestCase {
    var previewRepresentations = [
        "#Preview {\n    Text(\"TestView\")\n}\n",
        "#Preview {\n    Text(\"TestView_Prefire\")\n        .prefireEnabled()\n}\n"
    ]

    let source = #file

    func test_loadRawPreviewBodiesDefaultEnable() async {
        #if swift(>=5.9)
        let bodies = await PreviewLoader.loadRawPreviewBodies(for: [source], defaultEnabled: true)

        XCTAssertEqual(bodies?.count, 2)
        XCTAssertEqual(bodies?["PreviewLoaderTests_0"], previewRepresentations[0])
        XCTAssertEqual(bodies?["PreviewLoaderTests_1"], previewRepresentations[1])
        #endif
    }

    func test_loadRawPreviewBodiesDefaultDisabled() async {
        #if swift(>=5.9)
        let bodies = await PreviewLoader.loadRawPreviewBodies(for: [source], defaultEnabled: false)

        XCTAssertEqual(bodies?.count, 1)
        XCTAssertEqual(bodies?["PreviewLoaderTests_0"], previewRepresentations[1])
        #endif
    }
}

import SwiftUI

#if swift(>=5.9)
#Preview {
    Text("TestView")
}

#Preview {
    Text("TestView_Prefire")
        .prefireEnabled()
}

#Preview {
    Text("TestView_Ignored")
        .prefireIgnored()
}
#endif

extension View {
    func prefireEnabled() -> some View {
        self
    }

    func prefireIgnored() -> some View {
        self
    }
}
