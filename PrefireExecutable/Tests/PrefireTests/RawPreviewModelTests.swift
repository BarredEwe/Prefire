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
        let rawPreviewModel = makePreviewModel(from: previewBodyWithName)

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
        let rawPreviewModel = makePreviewModel(from: previewBodyWithoutName, filename: "TestView")
        
        XCTAssertEqual(rawPreviewModel?.body, "VStack {\n        Text(name)\n    }\n    .snapshot(delay: 8)")
        XCTAssertEqual(rawPreviewModel?.properties, "@State var name: String = \"TestView\"")
        XCTAssertEqual(rawPreviewModel?.displayName, "TestView_0")
        XCTAssertEqual(rawPreviewModel?.traits, [".sizeThatFitsLayout"])
    }

    func test_initWithArguments() {
        let previewBodyWithArguments = """
        #Preview("TextView", traits: .sizeThatFitsLayout, arguments: ["- A", "- B", "- C"]) { suffix in
            Text("1 \\(suffix)")
        }

        """
        let rawPreviewModel = makePreviewModel(from: previewBodyWithArguments)

        XCTAssertEqual(rawPreviewModel?.body, "Text(\"1 \\(suffix)\")")
        XCTAssertEqual(rawPreviewModel?.properties, nil)
        XCTAssertEqual(rawPreviewModel?.displayName, "TextView")
        XCTAssertEqual(rawPreviewModel?.traits, [".sizeThatFitsLayout"])
        XCTAssertEqual(rawPreviewModel?.arguments, "[\"- A\", \"- B\", \"- C\"]")
        XCTAssertEqual(rawPreviewModel?.argumentPattern, "suffix")
        XCTAssertEqual(rawPreviewModel?.hasArguments, true)
    }

    func test_initWithTupleArguments() {
        let previewBodyWithArguments = """
        #Preview("TextView", traits: .sizeThatFitsLayout, arguments: [("1", "- A"), ("2", "- B")]) { prefix, suffix in
            Text("\\(prefix) \\(suffix)")
        }

        """
        let rawPreviewModel = makePreviewModel(from: previewBodyWithArguments)

        XCTAssertEqual(rawPreviewModel?.body, "Text(\"\\(prefix) \\(suffix)\")")
        XCTAssertEqual(rawPreviewModel?.arguments, "[(\"1\", \"- A\"), (\"2\", \"- B\")]")
        XCTAssertEqual(rawPreviewModel?.argumentPattern, "(prefix, suffix)")
        XCTAssertEqual(rawPreviewModel?.hasArguments, true)
    }

    func test_initWithMultilineArgumentsSignature() {
        let previewBodyWithArguments = """
        #Preview(
            "TextView",
            traits: .sizeThatFitsLayout,
            arguments: ["- A", "- B"]
        ) { suffix in
            Text("1 \\(suffix)")
        }

        """
        let rawPreviewModel = makePreviewModel(from: previewBodyWithArguments)

        XCTAssertEqual(rawPreviewModel?.body, "Text(\"1 \\(suffix)\")")
        XCTAssertEqual(rawPreviewModel?.displayName, "TextView")
        XCTAssertEqual(rawPreviewModel?.traits, [".sizeThatFitsLayout"])
        XCTAssertEqual(rawPreviewModel?.arguments, "[\"- A\", \"- B\"]")
        XCTAssertEqual(rawPreviewModel?.argumentPattern, "suffix")
        XCTAssertEqual(rawPreviewModel?.hasArguments, true)
    }
    
    func test_initWithMultipleTraits() {
        let previewBodyWithMultipleTraits = """
        #Preview("TestViewName", traits: .device, .sizeThatFitsLayout) {
            Text("TestView")
        }

        """
        let rawPreviewModel = makePreviewModel(from: previewBodyWithMultipleTraits)

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
        let rawPreviewModel = makePreviewModel(from: previewBodyWithFunctionTrait)

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
        let rawPreviewModel = makePreviewModel(from: previewBodyWithMixedTraits)

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
        let rawPreviewModel = makePreviewModel(from: previewBodyWithoutTraits)

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
        let rawPreviewModel = makePreviewModel(from: previewBodyWithMultipleFunctionTraits)

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
        let rawPreviewModel = makePreviewModel(from: previewBodyWithComplexTraits)

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
        let rawPreviewModel = makePreviewModel(from: previewBodyWithNestedParentheses)

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
        let rawPreviewModel = makePreviewModel(from: previewBodyWithNestedParentheses)

        XCTAssertEqual(rawPreviewModel?.body, "ForEach(foo, id: \\.self) {\n        Text($0.formatted())\n    }")
        XCTAssertEqual(rawPreviewModel?.properties, "@State var foo = [\n        1, 2, 3\n    ]")
        XCTAssertEqual(rawPreviewModel?.displayName, "Test_0")
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
        let rawPreviewModel = makePreviewModel(from: previewBodyWithNestedParentheses)

        XCTAssertEqual(rawPreviewModel?.body, "var hoge = \"Test\"\nForEach(foo, id: \\.self) {\n        Text($0.formatted())\n    }")
        XCTAssertEqual(rawPreviewModel?.properties, "@State var foo = [\n        1, 2, 3\n    ]\n@State var name: String = \"TestView\"")
        XCTAssertEqual(rawPreviewModel?.displayName, "Test_0")
        XCTAssertEqual(rawPreviewModel?.traits, [".device"])
    }
    
    func test_uikitPreview() {
        let previewBodyWithNestedParentheses = """
        #Preview {
            let viewController = UIViewController()
            viewController.view.backgroundColor = .green
            return viewController
        }

        """
        let rawPreviewModel = makePreviewModel(from: previewBodyWithNestedParentheses)

        XCTAssertEqual(rawPreviewModel?.body, "let viewController = UIViewController()\nviewController.view.backgroundColor = .green\nreturn viewController")
        XCTAssertEqual(rawPreviewModel?.properties, nil)
        XCTAssertEqual(rawPreviewModel?.displayName, "Test_0")
        XCTAssertEqual(rawPreviewModel?.traits, [".device"])
    }

    func test_initWithSingleLineBody() {
        let previewBody = "#Preview(\"SingleLine\", traits: .sizeThatFitsLayout) { Text(\"TestView\") }\n"
        let rawPreviewModel = makePreviewModel(from: previewBody)

        XCTAssertEqual(rawPreviewModel?.body, "Text(\"TestView\")")
        XCTAssertEqual(rawPreviewModel?.properties, nil)
        XCTAssertEqual(rawPreviewModel?.displayName, "SingleLine")
        XCTAssertEqual(rawPreviewModel?.traits, [".sizeThatFitsLayout"])
    }

    func test_extractsFixedLayoutExpressions() {
        let source = """
        #Preview("Fixed", traits: .fixedLayout(width: Layout.width, height: 320 + padding)) {
            Text("TestView")
        }
        """

        let rawPreviewModel = makePreviewModel(from: source)

        XCTAssertEqual(rawPreviewModel?.fixedLayoutWidth, "Layout.width")
        XCTAssertEqual(rawPreviewModel?.fixedLayoutHeight, "320 + padding")
    }

    func test_hasNoFixedLayoutWhenTraitIsAbsent() {
        let rawPreviewModel = makePreviewModel(from: "#Preview { Text(\"TestView\") }")

        XCTAssertNil(rawPreviewModel?.fixedLayoutWidth)
        XCTAssertNil(rawPreviewModel?.fixedLayoutHeight)
    }
}

private func makePreviewModel(from source: String, filename: String = "Test") -> RawPreviewModel? {
    PreviewLoader.previewModels(from: source, filename: filename, defaultEnabled: true)?["\(filename)_0"]
}
