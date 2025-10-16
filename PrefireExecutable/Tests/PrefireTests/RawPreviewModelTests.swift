import Foundation
@testable import PrefireCore
import XCTest

class RawPreviewModelTests: XCTestCase {
    func test_initWithName() {
        let previewBodyWithName = """
        #Preview("TestViewName", traits: .sizeThatFitsLayout) {
            Text("TestView")
        }

        """
        let rawPreviewModel = RawPreviewModel(from: previewBodyWithName, filename: "Test")

        XCTAssertEqual(rawPreviewModel?.body, "Text(\"TestView\")")
        XCTAssertEqual(rawPreviewModel?.properties, nil)
        XCTAssertEqual(rawPreviewModel?.displayName, "TestViewName")
        XCTAssertEqual(rawPreviewModel?.traits, [".sizeThatFitsLayout"])
    }

    func test_initWithoutName() {
        let previewBodyWithoutName = """
        #Preview(traits: .sizeThatFitsLayout) {
            @Previewable @State var name: String = "TestView"

            VStack {
                Text(name)
            }
            .snapshot(delay: 8)
        }

        """
        let rawPreviewModel = RawPreviewModel(from: previewBodyWithoutName, filename: "TestView")
        
        XCTAssertEqual(rawPreviewModel?.body, "VStack {\n        Text(name)\n    }\n    .snapshot(delay: 8)")
        XCTAssertEqual(rawPreviewModel?.properties, "@State var name: String = \"TestView\"")
        XCTAssertEqual(rawPreviewModel?.displayName, "TestView")
        XCTAssertEqual(rawPreviewModel?.traits, [".sizeThatFitsLayout"])
    }
    
    func test_initWithMultipleTraits() {
        let previewBodyWithMultipleTraits = """
        #Preview("TestViewName", traits: .device, .sizeThatFitsLayout) {
            Text("TestView")
        }

        """
        let rawPreviewModel = RawPreviewModel(from: previewBodyWithMultipleTraits, filename: "Test")

        XCTAssertEqual(rawPreviewModel?.body, "Text(\"TestView\")")
        XCTAssertEqual(rawPreviewModel?.properties, nil)
        XCTAssertEqual(rawPreviewModel?.displayName, "TestViewName")
        XCTAssertEqual(rawPreviewModel?.traits, [".device", ".sizeThatFitsLayout"])
    }
    
    func test_initWithFunctionStyleTrait() {
        let previewBodyWithFunctionTrait = """
        #Preview("TestViewName", traits: .myTrait("one", 2)) {
            Text("TestView")
        }

        """
        let rawPreviewModel = RawPreviewModel(from: previewBodyWithFunctionTrait, filename: "Test")

        XCTAssertEqual(rawPreviewModel?.body, "Text(\"TestView\")")
        XCTAssertEqual(rawPreviewModel?.properties, nil)
        XCTAssertEqual(rawPreviewModel?.displayName, "TestViewName")
        XCTAssertEqual(rawPreviewModel?.traits, [".myTrait(\"one\", 2)"])
    }
    
    func test_initWithMixedTraits() {
        let previewBodyWithMixedTraits = """
        #Preview("TestViewName", traits: .device, .myTrait("test"), .sizeThatFitsLayout) {
            Text("TestView")
        }

        """
        let rawPreviewModel = RawPreviewModel(from: previewBodyWithMixedTraits, filename: "Test")

        XCTAssertEqual(rawPreviewModel?.body, "Text(\"TestView\")")
        XCTAssertEqual(rawPreviewModel?.properties, nil)
        XCTAssertEqual(rawPreviewModel?.displayName, "TestViewName")
        XCTAssertEqual(rawPreviewModel?.traits, [".device", ".myTrait(\"test\")", ".sizeThatFitsLayout"])
    }
    
    func test_initWithoutTraits() {
        let previewBodyWithoutTraits = """
        #Preview("TestViewName") {
            Text("TestView")
        }

        """
        let rawPreviewModel = RawPreviewModel(from: previewBodyWithoutTraits, filename: "Test")

        XCTAssertEqual(rawPreviewModel?.body, "Text(\"TestView\")")
        XCTAssertEqual(rawPreviewModel?.properties, nil)
        XCTAssertEqual(rawPreviewModel?.displayName, "TestViewName")
        XCTAssertEqual(rawPreviewModel?.traits, [".device"]) // Should default to .device
    }
    
    func test_initWithMultipleFunctionStyleTraits() {
        let previewBodyWithMultipleFunctionTraits = """
        #Preview("TestViewName", traits: .myTrait("param1", 123), .anotherTrait("hello", "world")) {
            Text("TestView")
        }

        """
        let rawPreviewModel = RawPreviewModel(from: previewBodyWithMultipleFunctionTraits, filename: "Test")

        XCTAssertEqual(rawPreviewModel?.body, "Text(\"TestView\")")
        XCTAssertEqual(rawPreviewModel?.properties, nil)
        XCTAssertEqual(rawPreviewModel?.displayName, "TestViewName")
        XCTAssertEqual(rawPreviewModel?.traits, [".myTrait(\"param1\", 123)", ".anotherTrait(\"hello\", \"world\")"])
    }
    
    func test_initWithComplexMixedTraits() {
        let previewBodyWithComplexTraits = """
        #Preview("TestViewName", traits: .device, .myTrait("test", 42), .sizeThatFitsLayout, .customFunc(true, "value")) {
            Text("TestView")
        }

        """
        let rawPreviewModel = RawPreviewModel(from: previewBodyWithComplexTraits, filename: "Test")

        XCTAssertEqual(rawPreviewModel?.body, "Text(\"TestView\")")
        XCTAssertEqual(rawPreviewModel?.properties, nil)
        XCTAssertEqual(rawPreviewModel?.displayName, "TestViewName")
        XCTAssertEqual(rawPreviewModel?.traits, [".device", ".myTrait(\"test\", 42)", ".sizeThatFitsLayout", ".customFunc(true, \"value\")"])
    }
    
    func test_initWithNestedParenthesesInTraits() {
        let previewBodyWithNestedParentheses = """
        #Preview("TestViewName", traits: .complexTrait(nested("inner", value), other(1, 2)), .device) {
            Text("TestView")
        }

        """
        let rawPreviewModel = RawPreviewModel(from: previewBodyWithNestedParentheses, filename: "Test")

        XCTAssertEqual(rawPreviewModel?.body, "Text(\"TestView\")")
        XCTAssertEqual(rawPreviewModel?.properties, nil)
        XCTAssertEqual(rawPreviewModel?.displayName, "TestViewName")
        XCTAssertEqual(rawPreviewModel?.traits, [".complexTrait(nested(\"inner\", value), other(1, 2))", ".device"])
    }
    
    func test_initWithMultilineProperty() {
        let previewBodyWithNestedParentheses = """
        #Preview {
            @Previewable @State var foo = [
                1, 2, 3
            ]
            ForEach(foo, id: \\.self) {
                Text($0.formatted())
            }
        }

        """
        let rawPreviewModel = RawPreviewModel(from: previewBodyWithNestedParentheses, filename: "Test")

        XCTAssertEqual(rawPreviewModel?.body, "ForEach(foo, id: \\.self) {\n        Text($0.formatted())\n    }")
        XCTAssertEqual(rawPreviewModel?.properties, "@State var foo = [\n        1, 2, 3\n    ]")
        XCTAssertEqual(rawPreviewModel?.displayName, "Test")
        XCTAssertEqual(rawPreviewModel?.traits, [".device"])
    }
    
    func test_initWithMultilineProperties() {
        let previewBodyWithNestedParentheses = """
        #Preview {
            @Previewable @State var foo = [
                1, 2, 3
            ]
            @Previewable @State var name: String = "TestView"
            var hoge = "Test"
            ForEach(foo, id: \\.self) {
                Text($0.formatted())
            }
        }

        """
        let rawPreviewModel = RawPreviewModel(from: previewBodyWithNestedParentheses, filename: "Test")

        XCTAssertEqual(rawPreviewModel?.body, "ForEach(foo, id: \\.self) {\n        Text($0.formatted())\n    }")
        XCTAssertEqual(rawPreviewModel?.properties, "@State var foo = [\n        1, 2, 3\n    ]\n@State var name: String = \"TestView\"")
        XCTAssertEqual(rawPreviewModel?.displayName, "Test")
        XCTAssertEqual(rawPreviewModel?.traits, [".device"])
    }
}
