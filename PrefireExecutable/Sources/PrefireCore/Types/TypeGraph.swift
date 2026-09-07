import Foundation

/// Resolved conformance information for the scanned types.
///
/// Inheritance is followed transitively through the types found in the sources, so a type declared
/// as `struct Foo: MyProvider` where `protocol MyProvider: PrefireProvider` is still reported as
/// being based on `PrefireProvider`.
struct TypeGraph {
    let types: [ParsedType]

    /// Transitive inherited names per type name, including the names written verbatim.
    private let basedByTypeName: [String: Set<String>]

    private let declaredByName: [String: ParsedType]

    init(types: [ParsedType]) {
        self.types = types

        var declared: [String: ParsedType] = [:]
        for type in types where !type.isExtension {
            declared[type.name] = type
            // Nested types are also reachable by their short name.
            if declared[type.localName] == nil { declared[type.localName] = type }
        }
        // Extension-only entries still carry conformances worth following.
        for type in types where declared[type.name] == nil {
            declared[type.name] = type
        }
        declaredByName = declared

        var based: [String: Set<String>] = [:]
        for type in types {
            based[type.name] = Self.transitiveInheritedNames(of: type, declaredByName: declared)
        }
        basedByTypeName = based
    }

    /// All names `type` is based on, directly or transitively.
    func based(of type: ParsedType) -> Set<String> {
        basedByTypeName[type.name] ?? []
    }

    /// Names from ``based(of:)`` that resolve to a protocol declared in the sources.
    func implements(of type: ParsedType) -> Set<String> {
        based(of: type).filter { declaredByName[$0]?.kind == .protocol }
    }

    /// Names from ``based(of:)`` that resolve to a class declared in the sources.
    func inherits(of type: ParsedType) -> Set<String> {
        based(of: type).filter { declaredByName[$0]?.kind == .class }
    }

    /// Types conforming to `protocolName`, directly or through another protocol.
    ///
    /// Extension-only placeholders are excluded: the conforming type has to be declared in the
    /// scanned sources for the generated code to be able to name it.
    func types(conformingTo protocolName: String) -> [ParsedType] {
        types.filter { type in
            guard !type.isExtension, type.kind != .protocol else { return false }
            return based(of: type).contains(protocolName)
        }
    }

    private static func transitiveInheritedNames(
        of type: ParsedType,
        declaredByName: [String: ParsedType]
    ) -> Set<String> {
        var result: Set<String> = []
        var queue = Array(type.inheritedNames)
        var visited: Set<String> = [type.name]

        while let name = queue.popLast() {
            guard result.insert(name).inserted else { continue }
            guard let parent = declaredByName[name], visited.insert(parent.name).inserted else { continue }
            queue.append(contentsOf: parent.inheritedNames)
        }

        return result
    }
}
