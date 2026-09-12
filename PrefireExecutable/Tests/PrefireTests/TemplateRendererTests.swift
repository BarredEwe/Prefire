import XCTest
@testable import PrefireCore

final class TemplateRendererTests: XCTestCase {
    private func context(from source: String) -> [String: Any] {
        StencilContext.make(
            graph: TypeGraph(types: TypeScanner.merge([TypeScanner.scan(contents: source)])),
            arguments: [:]
        )
    }

    func testAnnotatedFilterBooleanAndCollectionForms() throws {
        let context = context(from: """
        // sourcery: PrefireProvider
        struct Panel_Previews {}
        struct Other {}
        """)

        let boolean = try TemplateRenderer.render(
            template: #"{% if type.Panel_Previews|annotated:"PrefireProvider" %}yes{% endif %}"#,
            context: context
        )
        XCTAssertEqual(boolean, "yes")

        let collection = try TemplateRenderer.render(
            template: #"{% for t in types.types|annotated:"PrefireProvider" %}{{ t.name }}{% endfor %}"#,
            context: context
        )
        XCTAssertEqual(collection, "Panel_Previews")
    }

    func testBasedFilterCollectionForm() throws {
        let context = context(from: """
        struct Panel_Previews: PrefireProvider {}
        struct Other {}
        """)

        let rendered = try TemplateRenderer.render(
            template: #"{% for t in types.types|based:"PrefireProvider" %}{{ t.name }}{% endfor %}"#,
            context: context
        )
        XCTAssertEqual(rendered, "Panel_Previews")
    }

    func testReversedYieldsAnArray() throws {
        let context = context(from: """
        struct Alpha {}
        struct Beta {}
        """)

        let rendered = try TemplateRenderer.render(
            template: "{% for t in types.types|reversed %}{{ t.name }}{% endfor %}",
            context: context
        )
        XCTAssertEqual(rendered, "BetaAlpha")
    }
}
