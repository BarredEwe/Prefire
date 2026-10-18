import Foundation

/// Template context in the shape Sourcery provided (`types`, `type`, `argument`), so custom
/// templates keep working.
///
/// The type part depends only on the scanned sources, so it is built once and reused for every
/// rendered file.
struct StencilContext {
    private let types: [String: Any]
    private let typesByName: [String: [String: Any]]

    init(graph: TypeGraph) {
        let entries = graph.types.map { (type: $0, dictionary: Self.dictionary(for: $0, graph: graph)) }

        func dictionaries(where isIncluded: (ParsedType) -> Bool) -> [[String: Any]] {
            entries.filter { isIncluded($0.type) }.map(\.dictionary)
        }

        types = [
            "types": entries.map(\.dictionary),
            // Sourcery's `types.all` excludes protocols (and protocol compositions).
            "all": dictionaries { !$0.isExtension && $0.kind != .protocol },
            "protocols": dictionaries { $0.kind == .protocol },
            "classes": dictionaries { $0.kind == .class },
            "structs": dictionaries { $0.kind == .struct },
            "enums": dictionaries { $0.kind == .enum },
            "extensions": dictionaries(where: \.isExtension),
            "based": Self.group(entries, by: graph.based(of:)),
            "implementing": Self.group(entries, by: graph.implements(of:)),
            "inheriting": Self.group(entries, by: graph.inherits(of:))
        ]
        typesByName = Dictionary(entries.map { ($0.type.name, $0.dictionary) }) { first, _ in first }
    }

    func dictionary(arguments: [String: NSObject]) -> [String: Any] {
        [
            "types": types,
            "type": typesByName,
            "argument": arguments,
            "functions": [Any]()
        ]
    }

    private static func dictionary(for type: ParsedType, graph: TypeGraph) -> [String: Any] {
        [
            "name": type.name,
            "localName": type.localName,
            "kind": type.kind.rawValue,
            "accessLevel": type.accessLevel,
            "isExtension": type.isExtension,
            "annotations": type.annotations,
            "inheritedTypes": type.inherits,
            "based": lookupTable(graph.based(of: type)),
            "implements": lookupTable(graph.implements(of: type)),
            "inherits": lookupTable(graph.inherits(of: type))
        ]
    }

    /// `type.based.SomeName` has to resolve to a truthy value, so names map to themselves.
    private static func lookupTable(_ names: Set<String>) -> [String: String] {
        Dictionary(uniqueKeysWithValues: names.map { ($0, $0) })
    }

    private static func group(
        _ entries: [(type: ParsedType, dictionary: [String: Any])],
        by names: (ParsedType) -> Set<String>
    ) -> [String: [[String: Any]]] {
        var grouped: [String: [[String: Any]]] = [:]
        for entry in entries {
            for name in names(entry.type) {
                grouped[name, default: []].append(entry.dictionary)
            }
        }
        return grouped
    }
}
