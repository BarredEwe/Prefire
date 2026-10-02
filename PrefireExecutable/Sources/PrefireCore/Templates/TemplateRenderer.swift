import Foundation
import Stencil
import StencilSwiftKit

enum TemplateRenderer {
    static func render(template: String, context: [String: Any]) throws -> String {
        try environment().renderTemplate(string: template, context: context)
    }

    private static func environment() -> Environment {
        var extensions = stencilSwiftEnvironment().extensions
        extensions.append(prefireExtension())
        return Environment(extensions: extensions, templateClass: BlankLineCollapsingTemplate.self)
    }

    private static func prefireExtension() -> Extension {
        let ext = Extension()

        ext.registerFilter("annotated") { value, arguments in
            guard let annotation = arguments.first as? String else {
                throw TemplateSyntaxError("'annotated' filter takes a single string argument")
            }
            func isAnnotated(_ type: [String: Any]) -> Bool {
                ParsedType.annotations(type["annotations"] as? [String: String] ?? [:], match: annotation)
            }
            if let types = typeDictionaries(value) {
                return types.filter(isAnnotated)
            }
            return (value as? [String: Any]).map(isAnnotated) ?? false
        }

        registerConformanceFilter(on: ext, named: "based")
        registerConformanceFilter(on: ext, named: "implements")
        registerConformanceFilter(on: ext, named: "inherits")

        ext.registerFilter("count") { value in
            if let array = value as? [Any] { return array.count }
            if let dictionary = value as? [String: Any] { return dictionary.count }
            if let string = value as? String { return string.count }
            return nil
        }

        ext.registerFilter("isEmpty") { value in
            if let array = value as? [Any] { return array.isEmpty }
            if let dictionary = value as? [String: Any] { return dictionary.isEmpty }
            if let string = value as? String { return string.isEmpty }
            return nil
        }

        ext.registerFilter("toArray") { value in
            if let array = value as? [Any] { return array }
            return value.map { [$0] }
        }

        ext.registerFilter("last") { value in
            (value as? [Any])?.last
        }

        ext.registerFilter("reversed") { value in
            (value as? [Any]).map { Array($0.reversed()) }
        }

        return ext
    }

    /// `type|based:"Foo"` (boolean) or `types.types|based:"Foo"` (filtered list).
    private static func registerConformanceFilter(on ext: Extension, named name: String) {
        ext.registerFilter(name) { value, arguments in
            guard let expected = arguments.first as? String else {
                throw TemplateSyntaxError("'\(name)' filter takes a single string argument")
            }
            if let types = typeDictionaries(value) {
                return types.filter { type in
                    guard let names = type[name] as? [String: String] else { return false }
                    return names[expected] != nil
                }
            }
            guard let type = value as? [String: Any], let names = type[name] as? [String: String] else {
                return false
            }
            return names[expected] != nil
        }
    }

    private static func typeDictionaries(_ value: Any?) -> [[String: Any]]? {
        guard let array = value as? [Any] else { return nil }
        let types = array.compactMap { $0 as? [String: Any] }
        return types.count == array.count ? types : nil
    }
}

/// Collapses blank lines that `{% if %}` / `{% for %}` leave behind.
///
/// Stencil keeps the newline after a block tag, so a readable template would otherwise emit runs of
/// empty lines. Marked blank lines in the source survive the cleanup.
private final class BlankLineCollapsingTemplate: Template {
    /// Marks blank lines the template author wrote on purpose, so they survive the cleanup.
    private static let marker = "\u{000b}"

    private static let blankLineRuns = try! NSRegularExpression(pattern: "\\n([ \\t]*\\n)+")

    /// A newline directly followed by another one; the lookahead keeps runs from overlapping.
    private static let intentionalBlankLines = try! NSRegularExpression(pattern: "\\n(?=\\n)")

    required init(templateString: String, environment: Environment? = nil, name: String? = nil) {
        super.init(templateString: Self.markIntentionalBlankLines(templateString), environment: environment, name: name)
    }

    override func render(_ dictionary: [String: Any]? = nil) throws -> String {
        let rendered = try super.render(dictionary)
        let collapsed = Self.blankLineRuns.stringByReplacingMatches(
            in: rendered,
            range: NSRange(location: 0, length: rendered.utf16.count),
            withTemplate: "\n"
        )
        // A marked line holds nothing but the marker, so dropping it restores the blank line.
        return collapsed.replacingOccurrences(of: Self.marker, with: "")
    }

    private static func markIntentionalBlankLines(_ string: String) -> String {
        intentionalBlankLines.stringByReplacingMatches(
            in: string,
            range: NSRange(location: 0, length: string.utf16.count),
            withTemplate: "\n\(marker)"
        )
    }
}
