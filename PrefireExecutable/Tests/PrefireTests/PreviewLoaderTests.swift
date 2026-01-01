import Foundation
@testable import PrefireCore
import XCTest

class PreviewLoaderTests: XCTestCase {
    var previewRepresentations = [
        "#Preview {\n    Text(\"TestView\")\n}\n",
        "#Preview {\n    Text(\"TestView_Prefire\")\n        .prefireEnabled()\n}\n",
        "#Preview {\n    Text(\"TestPreview\")\n}\n",
        "#Preview {\n    Text(\"TestPreview_Prefire\")\n        .prefireEnabled()\n}\n",
        "#Preview(\"Preview with properties\") {\n    @Previewable @State var foo: Bool = false\n    Text(\"TestPreview_WithProperties\")\n}\n",
        "#Preview\n{\n    VStack\n    {\n        Text(\"Preview formatted with Allman\")\n    }\n}\n"
    ]

    let source = #filePath

    func test_loadRawPreviewBodiesDefaultEnable() async throws {
        let content = try String(contentsOf: URL(filePath: source), encoding: .utf8)
        let previews = PreviewLoader.previewBodies(from: content, defaultEnabled: true)

        XCTAssertEqual(previews?.count, 2)
        XCTAssertEqual(previews?[0], previewRepresentations[0])
        XCTAssertEqual(previews?[1], previewRepresentations[1])
    }
    
    func test_loadRawPreviewBodiesDefaultDisabled() async throws {
        let content = try String(contentsOf: URL(filePath: source), encoding: .utf8)
        let previews = PreviewLoader.previewBodies(from: content, defaultEnabled: false)
        
        XCTAssertEqual(previews?.count, 1)
        XCTAssertEqual(previews?[0], previewRepresentations[1])
    }
    
    func test_loadRawPreviewBodiesDefaultEnableAndUrlIsDirectory() async throws {
        let content = try String(contentsOf: URL(filePath: fixtureTestPreviewSource), encoding: .utf8)
        let previews = PreviewLoader.previewBodies(from: content, defaultEnabled: true)

        XCTAssertEqual(previews?.count, 4)
        XCTAssertEqual(previews?[0], previewRepresentations[2])
        XCTAssertEqual(previews?[1], previewRepresentations[3])
		XCTAssertEqual(previews?[2], previewRepresentations[4])
        XCTAssertEqual(previews?[3], previewRepresentations[5])
    }

    func test_loadRawPreviewBodiesDefaultDisabledAndUrlIsDirectory() async throws {
        let content = try String(contentsOf: URL(filePath: fixtureTestPreviewSource), encoding: .utf8)
        let previews = PreviewLoader.previewBodies(from: content, defaultEnabled: false)

        XCTAssertEqual(previews?.count, 1)
        XCTAssertEqual(previews?[0], previewRepresentations[3])
    }
}

// MARK: - Previews

import SwiftUI

#Preview {
    Text("TestView")
}

#Preview {
    Text("TestView_Prefire")
        .prefireEnabled()
}

#Preview {
    Text("TestView_Ignored")
        // Some comment
        .prefireIgnored() // Some comment
}

#Preview {
    Text("TestView_Ignored_One_Line").prefireIgnored() // Some comment
}

extension View {
    func prefireEnabled() -> some View {
        self
    }

    func prefireIgnored() -> some View {
        self
    }
}
