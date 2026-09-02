import Foundation

/// A type declaration found in the scanned sources.
///
/// This is the whole model the templates need: a name, what the declaration inherits from and the
/// `// prefire:` / `// sourcery:` annotations attached to it. Everything else Sourcery used to
/// expose (members, methods, generic parameters) was never read by any Prefire template.
struct ParsedType: Codable, Equatable {
    enum Kind: String, Codable {
        case `struct`
        case `class`
        case `enum`
        case `actor`
        case `protocol`
        /// A conformance added by an `extension` to a type declared outside the scanned sources.
        case unknown
    }

    /// Fully-qualified name, e.g. `Outer.Inner`.
    var name: String

    /// Unqualified name, e.g. `Inner`.
    var localName: String

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

    /// True when the type itself was not declared in the scanned sources and is only known
    /// through an `extension`.
    var isExtension: Bool

    init(
        name: String,
        localName: String,
        kind: Kind,
        accessLevel: String = "internal",
        inherits: [String] = [],
        annotations: [String: String] = [:],
        isExtension: Bool = false
    ) {
        self.name = name
        self.localName = localName
        self.kind = kind
        self.accessLevel = accessLevel
        self.inherits = inherits
        self.annotations = annotations
        self.isExtension = isExtension
    }
}

extension ParsedType {
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
        guard let equalsIndex = annotation.firstIndex(of: "=") else {
            return annotations[annotation] != nil
        }

        let key = annotation[annotation.startIndex ..< equalsIndex].trimmingCharacters(in: .whitespaces)
        let value = annotation[annotation.index(after: equalsIndex)...].trimmingCharacters(in: .whitespaces)
        return annotations[key] == value
    }
}
