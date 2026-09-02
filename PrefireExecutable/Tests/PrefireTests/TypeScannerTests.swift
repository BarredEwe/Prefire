import XCTest
@testable import PrefireCore

final class TypeScannerTests: XCTestCase {
    private func graph(_ sources: String...) -> TypeGraph {
        TypeGraph(types: TypeScanner.merge(sources.map { TypeScanner.scan(contents: $0) }))
    }

    private func type(named name: String, in graph: TypeGraph) throws -> ParsedType {
        try XCTUnwrap(graph.types.first { $0.name == name })
    }

    // MARK: - Conformances

    func test_directConformance() throws {
        let graph = graph("struct Panel_Previews: PreviewProvider, PrefireProvider {}")
        let panel = try type(named: "Panel_Previews", in: graph)

        XCTAssertEqual(graph.based(of: panel), ["PreviewProvider", "PrefireProvider"])
        XCTAssertEqual(graph.types(conformingTo: "PrefireProvider").map(\.name), ["Panel_Previews"])
    }

    /// The case Sourcery's `based` used to cover: conformance inherited through another protocol.
    func test_conformanceThroughAnotherProtocol() throws {
        let graph = graph(
            """
            protocol PrefireProvider {}
            protocol TeamProvider: PrefireProvider {}
            protocol ScreenProvider: TeamProvider {}
            struct Panel_Previews: ScreenProvider {}
            """
        )
        let panel = try type(named: "Panel_Previews", in: graph)

        XCTAssertTrue(graph.based(of: panel).contains("PrefireProvider"))
        XCTAssertTrue(graph.implements(of: panel).contains("PrefireProvider"))
        XCTAssertEqual(graph.types(conformingTo: "PrefireProvider").map(\.name), ["Panel_Previews"])
    }

    func test_conformanceAddedByExtension() throws {
        let graph = graph(
            "struct Panel_Previews: PreviewProvider {}",
            "extension Panel_Previews: PrefireProvider {}"
        )
        let panel = try type(named: "Panel_Previews", in: graph)

        XCTAssertTrue(graph.based(of: panel).contains("PrefireProvider"))
        XCTAssertFalse(panel.isExtension, "A real declaration must win over the extension placeholder")
        XCTAssertEqual(graph.types(conformingTo: "PrefireProvider").map(\.name), ["Panel_Previews"])
    }

    /// An extension of a type declared elsewhere is kept, but is not offered as a generatable type:
    /// the generated code could not name it reliably.
    func test_extensionOfUnknownTypeIsNotGeneratable() {
        let graph = graph("extension SomeExternalView: PrefireProvider {}")

        XCTAssertEqual(graph.types.count, 1)
        XCTAssertTrue(graph.types[0].isExtension)
        XCTAssertTrue(graph.types(conformingTo: "PrefireProvider").isEmpty)
    }

    func test_moduleQualifiedConformanceMatchesUnqualifiedName() throws {
        let graph = graph("struct Panel_Previews: Prefire.PrefireProvider {}")
        let panel = try type(named: "Panel_Previews", in: graph)

        XCTAssertTrue(graph.based(of: panel).contains("PrefireProvider"))
        XCTAssertTrue(graph.based(of: panel).contains("Prefire.PrefireProvider"))
    }

    func test_inheritanceCycleDoesNotHang() throws {
        let graph = graph(
            """
            protocol A: B {}
            protocol B: A {}
            struct Panel_Previews: A {}
            """
        )

        XCTAssertEqual(graph.based(of: try type(named: "Panel_Previews", in: graph)), ["A", "B"])
    }

    func test_classInheritanceIsReportedAsInherits() throws {
        let graph = graph(
            """
            class Base {}
            class Child: Base {}
            """
        )

        XCTAssertEqual(graph.inherits(of: try type(named: "Child", in: graph)), ["Base"])
    }

    // MARK: - Names and modifiers

    func test_nestedTypesAreQualified() {
        let graph = graph(
            """
            enum Outer {
                struct Inner: PrefireProvider {}
            }
            """
        )

        XCTAssertEqual(graph.types.map(\.name).sorted(), ["Outer", "Outer.Inner"])
        XCTAssertEqual(graph.types(conformingTo: "PrefireProvider").map(\.name), ["Outer.Inner"])
        XCTAssertEqual(graph.types(conformingTo: "PrefireProvider").map(\.localName), ["Inner"])
    }

    func test_accessLevel() throws {
        let graph = graph(
            """
            public struct Open_Previews: PrefireProvider {}
            private struct Hidden_Previews: PrefireProvider {}
            struct Default_Previews: PrefireProvider {}
            """
        )

        XCTAssertEqual(try type(named: "Open_Previews", in: graph).accessLevel, "public")
        XCTAssertEqual(try type(named: "Hidden_Previews", in: graph).accessLevel, "private")
        XCTAssertEqual(try type(named: "Default_Previews", in: graph).accessLevel, "internal")
    }

    func test_actorsAndEnumsAreScanned() {
        let graph = graph(
            """
            actor Worker {}
            enum Namespace {}
            """
        )

        XCTAssertEqual(graph.types.first { $0.name == "Worker" }?.kind, .actor)
        XCTAssertEqual(graph.types.first { $0.name == "Namespace" }?.kind, .enum)
    }

    // MARK: - Annotations

    func test_annotations() throws {
        let graph = graph(
            """
            // sourcery: PrefireProvider
            struct Legacy_Previews {}

            // prefire: PrefireProvider
            struct Modern_Previews {}

            /// prefire: userStory = "Onboarding"
            struct Documented_Previews {}
            """
        )

        XCTAssertTrue(try type(named: "Legacy_Previews", in: graph).isAnnotated(with: "PrefireProvider"))
        XCTAssertTrue(try type(named: "Modern_Previews", in: graph).isAnnotated(with: "PrefireProvider"))

        let documented = try type(named: "Documented_Previews", in: graph)
        XCTAssertEqual(documented.annotations["userStory"], "Onboarding")
        XCTAssertTrue(documented.isAnnotated(with: "userStory = Onboarding"))
        XCTAssertFalse(documented.isAnnotated(with: "userStory = Checkout"))
    }

    func test_annotationOnDeclarationWithAttributes() throws {
        let graph = graph(
            """
            // sourcery: PrefireProvider
            @available(iOS 17, *)
            struct Panel_Previews {}
            """
        )

        XCTAssertTrue(try type(named: "Panel_Previews", in: graph).isAnnotated(with: "PrefireProvider"))
    }

    func test_unrelatedCommentsAreNotAnnotations() throws {
        let graph = graph(
            """
            // A plain comment about the preview.
            struct Panel_Previews {}
            """
        )

        XCTAssertTrue(try type(named: "Panel_Previews", in: graph).annotations.isEmpty)
    }
}
