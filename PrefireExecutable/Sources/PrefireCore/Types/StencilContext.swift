import Foundation

enum StencilContext {
    static func make(graph: TypeGraph, arguments: [String: NSObject]) -> [String: Any] {
        let dictionaries = graph.types.map { dictionary(for: $0, graph: graph) }

        var typesByName: [String: [String: Any]] = [:]
        for dictionary in dictionaries {
            guard let name = dictionary["name"] as? String else { continue }
            typesByName[name] = dictionary
        }

        let declared = dictionaries.filter { $0["isExtension"] as? Bool == false }
        // Sourcery's `types.all` excludes protocols (and protocol compositions).
        let all = declared.filter { $0["kind"] as? String != "protocol" }

        return [
            "types": [
                "types": dictionaries,
                "all": all,
                "protocols": declared.filter { $0["kind"] as? String == "protocol" },
                "classes": declared.filter { $0["kind"] as? String == "class" },
                "structs": declared.filter { $0["kind"] as? String == "struct" },
                "enums": declared.filter { $0["kind"] as? String == "enum" },
                "extensions": dictionaries.filter { $0["isExtension"] as? Bool == true },
                "based": group(dictionaries, by: "based"),
                "implementing": group(dictionaries, by: "implements"),
                "inheriting": group(dictionaries, by: "inherits")
            ],
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

    private static func group(_ dictionaries: [[String: Any]], by key: String) -> [String: [[String: Any]]] {
        var grouped: [String: [[String: Any]]] = [:]
        for dictionary in dictionaries {
            guard let names = dictionary[key] as? [String: String] else { continue }
            for name in names.keys {
                grouped[name, default: []].append(dictionary)
            }
        }
        return grouped
    }
}
