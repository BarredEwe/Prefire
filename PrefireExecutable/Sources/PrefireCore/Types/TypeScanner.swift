import Foundation
import SwiftParser
import SwiftSyntax

enum TypeScanner {
    /// Scans one file. Types are returned in source order.
    static func scan(contents: String) -> [ParsedType] {
        let sourceFile = Parser.parse(source: contents)
        let visitor = TypeDeclarationVisitor()
        visitor.walk(sourceFile)
        return visitor.types
    }

    /// Merges per-file results, folding `extension` conformances into the type they extend.
    ///
    /// An extension of a type that was not declared in the scanned sources still produces an entry,
    /// so `extension SomeExternalType: PrefireProvider` is not silently dropped.
    static func merge(_ scanned: [[ParsedType]]) -> [ParsedType] {
        var types: [ParsedType] = []
        var indexByName: [String: Int] = [:]

        for fileTypes in scanned {
            for type in fileTypes {
                guard let existingIndex = indexByName[type.name] else {
                    indexByName[type.name] = types.count
                    types.append(type)
                    continue
                }
                fold(type, into: &types[existingIndex])
            }
        }

        // `extension MyApp.Panel_Previews` extends the `Panel_Previews` declared in the sources:
        // fold it in, or the template would emit a second, uncompilable `MyApp.Panel_Previews` test.
        var folded = IndexSet()
        for (index, type) in types.enumerated() where type.isExtension {
            guard let targetIndex = moduleQualifiedTarget(of: type.name, in: types, indexByName: indexByName) else {
                continue
            }
            fold(type, into: &types[targetIndex])
            folded.insert(index)
        }

        return types.enumerated().filter { !folded.contains($0.offset) }.map(\.element)
    }

    private static func fold(_ type: ParsedType, into existing: inout ParsedType) {
        for inherited in type.inherits where !existing.inherits.contains(inherited) {
            existing.inherits.append(inherited)
        }
        existing.annotations.merge(type.annotations) { current, _ in current }
        // A real declaration always wins over the placeholder an extension produces.
        if existing.isExtension, !type.isExtension {
            existing.kind = type.kind
            existing.accessLevel = type.accessLevel
        }
    }

    /// Index of the declared type `name` refers to once its leading module name is dropped.
    private static func moduleQualifiedTarget(
        of name: String,
        in types: [ParsedType],
        indexByName: [String: Int]
    ) -> Int? {
        var components = name.split(separator: ".")
        while components.count > 1 {
            components.removeFirst()
            if let index = indexByName[components.joined(separator: ".")], !types[index].isExtension {
                return index
            }
        }
        return nil
    }
}

private final class TypeDeclarationVisitor: SyntaxVisitor {
    private(set) var types: [ParsedType] = []

    /// Enclosing type names, so nested declarations get a qualified name.
    private var scope: [String] = []

    init() {
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        record(node, name: node.name, kind: .struct, inheritance: node.inheritanceClause, modifiers: node.modifiers)
    }

    override func visitPost(_ node: StructDeclSyntax) { scope.removeLast() }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        record(node, name: node.name, kind: .class, inheritance: node.inheritanceClause, modifiers: node.modifiers)
    }

    override func visitPost(_ node: ClassDeclSyntax) { scope.removeLast() }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        record(node, name: node.name, kind: .enum, inheritance: node.inheritanceClause, modifiers: node.modifiers)
    }

    override func visitPost(_ node: EnumDeclSyntax) { scope.removeLast() }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        record(node, name: node.name, kind: .actor, inheritance: node.inheritanceClause, modifiers: node.modifiers)
    }

    override func visitPost(_ node: ActorDeclSyntax) { scope.removeLast() }

    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        record(node, name: node.name, kind: .protocol, inheritance: node.inheritanceClause, modifiers: node.modifiers)
    }

    override func visitPost(_ node: ProtocolDeclSyntax) { scope.removeLast() }

    /// An extension contributes conformances to the type it extends, under that type's own name.
    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        let extendedName = node.extendedType.trimmedDescription

        types.append(
            ParsedType(
                name: extendedName,
                kind: .extension,
                accessLevel: Self.accessLevel(from: node.modifiers),
                inherits: Self.inheritedNames(from: node.inheritanceClause),
                annotations: AnnotationParser.parse(node.leadingTrivia)
            )
        )

        scope.append(extendedName)
        return .visitChildren
    }

    override func visitPost(_ node: ExtensionDeclSyntax) { scope.removeLast() }

    private func record(
        _ node: some SyntaxProtocol,
        name: TokenSyntax,
        kind: ParsedType.Kind,
        inheritance: InheritanceClauseSyntax?,
        modifiers: DeclModifierListSyntax
    ) -> SyntaxVisitorContinueKind {
        let localName = name.text.trimmingCharacters(in: .whitespaces)
        let qualifiedName = (scope + [localName]).joined(separator: ".")

        types.append(
            ParsedType(
                name: qualifiedName,
                kind: kind,
                accessLevel: Self.accessLevel(from: modifiers),
                inherits: Self.inheritedNames(from: inheritance),
                annotations: AnnotationParser.parse(node.leadingTrivia)
            )
        )

        scope.append(localName)
        return .visitChildren
    }

    private static func inheritedNames(from clause: InheritanceClauseSyntax?) -> [String] {
        guard let clause else { return [] }
        return clause.inheritedTypes.flatMap { names(from: $0.type) }
    }

    /// `A & B` is one `CompositionTypeSyntax`; flatten it so each name is a separate conformance.
    private static func names(from type: TypeSyntax) -> [String] {
        if let composition = type.as(CompositionTypeSyntax.self) {
            return composition.elements.flatMap { names(from: $0.type) }
        }
        let description = type.trimmedDescription
        return description.isEmpty ? [] : [description]
    }

    private static func accessLevel(from modifiers: DeclModifierListSyntax) -> String {
        let known: Set<String> = ["open", "public", "package", "internal", "fileprivate", "private"]
        for modifier in modifiers {
            let name = modifier.name.text
            if known.contains(name) { return name }
        }
        return "internal"
    }
}
