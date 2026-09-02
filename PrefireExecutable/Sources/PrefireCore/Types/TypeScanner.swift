import Foundation
import SwiftParser
import SwiftSyntax

/// Collects the type declarations a template needs from a Swift source file.
///
/// Replaces Sourcery's full-fidelity AST model: the templates only ever look at a type's name, its
/// conformances and its annotations, so that is all this scans for.
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

                var existing = types[existingIndex]
                for inherited in type.inherits where !existing.inherits.contains(inherited) {
                    existing.inherits.append(inherited)
                }
                existing.annotations.merge(type.annotations) { current, _ in current }
                // A real declaration always wins over the placeholder an extension produces.
                if existing.isExtension, !type.isExtension {
                    existing.kind = type.kind
                    existing.accessLevel = type.accessLevel
                    existing.isExtension = false
                }
                types[existingIndex] = existing
            }
        }

        return types
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
                localName: extendedName.split(separator: ".").last.map(String.init) ?? extendedName,
                kind: .unknown,
                accessLevel: Self.accessLevel(from: node.modifiers),
                inherits: Self.inheritedNames(from: node.inheritanceClause),
                annotations: AnnotationParser.parse(node.leadingTrivia),
                isExtension: true
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
                localName: localName,
                kind: kind,
                accessLevel: Self.accessLevel(from: modifiers),
                inherits: Self.inheritedNames(from: inheritance),
                annotations: AnnotationParser.parse(node.leadingTrivia),
                isExtension: false
            )
        )

        scope.append(localName)
        return .visitChildren
    }

    private static func inheritedNames(from clause: InheritanceClauseSyntax?) -> [String] {
        guard let clause else { return [] }
        return clause.inheritedTypes.map { $0.type.trimmedDescription }
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

/// Reads `// prefire:` and `// sourcery:` annotation comments preceding a declaration.
enum AnnotationParser {
    private static let prefixes = ["prefire:", "sourcery:"]

    static func parse(_ trivia: Trivia) -> [String: String] {
        var annotations: [String: String] = [:]

        for piece in trivia {
            let text: String
            switch piece {
            case let .lineComment(comment), let .docLineComment(comment):
                text = comment
            case let .blockComment(comment), let .docBlockComment(comment):
                text = comment
            default:
                continue
            }

            guard let body = annotationBody(in: text) else { continue }
            for entry in body.split(separator: ",") {
                let (key, value) = keyValue(from: String(entry))
                guard !key.isEmpty else { continue }
                annotations[key] = value
            }
        }

        return annotations
    }

    /// Strips comment delimiters and the `sourcery:`/`prefire:` marker.
    private static func annotationBody(in comment: String) -> String? {
        var text = comment
        for delimiter in ["///", "//", "/**", "/*", "*/"] {
            text = text.replacingOccurrences(of: delimiter, with: " ")
        }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        for prefix in prefixes where text.lowercased().hasPrefix(prefix) {
            return String(text.dropFirst(prefix.count))
        }
        return nil
    }

    private static func keyValue(from entry: String) -> (key: String, value: String) {
        guard let equalsIndex = entry.firstIndex(of: "=") else {
            return (entry.trimmingCharacters(in: .whitespaces), "true")
        }

        let key = entry[entry.startIndex ..< equalsIndex].trimmingCharacters(in: .whitespaces)
        var value = entry[entry.index(after: equalsIndex)...].trimmingCharacters(in: .whitespaces)
        if value.count >= 2, value.hasPrefix("\""), value.hasSuffix("\"") {
            value = String(value.dropFirst().dropLast())
        }
        return (key, value)
    }
}
