import Foundation

struct ParsedType: Codable, Equatable {
    enum Kind: String, Codable {
        case `struct`
        case `class`
        case `enum`
        case `actor`
        case `protocol`
        /// Conformance added by an `extension` of a type not declared in the scanned sources.
        case `extension`
    }

    /// Fully-qualified name, e.g. `Outer.Inner`.
    var name: String

    var kind: Kind

    /// `open`, `public`, `package`, `internal`, `fileprivate` or `private`.
    var accessLevel: String

    /// Names written in the declaration's inheritance clause, plus those added by extensions.
    ///
    /// Stored as written, so `Prefire.PrefireProvider` stays qualified. ``inheritedNames`` adds the
    /// unqualified spelling on top, so a template matching `PrefireProvider` finds it either way.
    var inherits: [String]

    /// Annotations from `// prefire:` / `// sourcery:` comments preceding the declaration.
    var annotations: [String: String]

    init(
        name: String,
        kind: Kind,
        accessLevel: String = "internal",
        inherits: [String] = [],
        annotations: [String: String] = [:]
    ) {
        self.name = name
        self.kind = kind
        self.accessLevel = accessLevel
        self.inherits = inherits
        self.annotations = annotations
    }
}

extension ParsedType {
    /// Unqualified name, e.g. `Inner`.
    var localName: String {
        name.split(separator: ".").last.map(String.init) ?? name
    }

    /// True when the type itself was not declared in the scanned sources and is only known
    /// through an `extension`.
    var isExtension: Bool {
        kind == .extension
    }

    /// Directly inherited names, both as written and unqualified.
    var inheritedNames: Set<String> {
        var names = Set<String>()
        for inherited in inherits {
            names.insert(inherited)
            if let last = inherited.split(separator: ".").last, last != inherited[...] {
                names.insert(String(last))
            }
        }
        return names
    }

    /// Matches Sourcery's `annotated:` filter, including its `key = value` form.
    func isAnnotated(with annotation: String) -> Bool {
        Self.annotations(annotations, match: annotation)
    }

    /// Shared with the `annotated:` template filter, which sees annotations already flattened into
    /// the template context.
    static func annotations(_ annotations: [String: String], match annotation: String) -> Bool {
        guard let equalsIndex = annotation.firstIndex(of: "=") else {
            return annotations[annotation] != nil
        }

        let key = annotation[annotation.startIndex ..< equalsIndex].trimmingCharacters(in: .whitespaces)
        let value = annotation[annotation.index(after: equalsIndex)...].trimmingCharacters(in: .whitespaces)
        return annotations[key] == value
    }
}
