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
            if let types = typeDictionaries(value) {
                return types.filter { ParsedType.isAnnotated($0, with: annotation) }
            }
            return typeDictionary(value).map { ParsedType.isAnnotated($0, with: annotation) } ?? false
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
            if let array = asArray(value) { return array }
            return value.map { [$0] }
        }

        ext.registerFilter("last") { value in
            asArray(value)?.last
        }

        ext.registerFilter("reversed") { value in
            asArray(value).map { Array($0.reversed()) }
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
            guard let type = typeDictionary(value), let names = type[name] as? [String: String] else {
                return false
            }
            return names[expected] != nil
        }
    }

    private static func typeDictionary(_ value: Any?) -> [String: Any]? {
        value as? [String: Any]
    }

    private static func typeDictionaries(_ value: Any?) -> [[String: Any]]? {
        guard let array = value as? [Any] else { return nil }
        let types = array.compactMap { $0 as? [String: Any] }
        return types.count == array.count ? types : nil
    }

    private static func asArray(_ value: Any?) -> [Any]? {
        value as? [Any]
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
        return Self.unmarkBlankLines(collapsed)
    }

    /// Applied twice: overlapping matches mean a single pass misses every other blank line.
    private static func markIntentionalBlankLines(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\n\n", with: "\n\(marker)\n")
            .replacingOccurrences(of: "\n\n", with: "\n\(marker)\n")
    }

    private static func unmarkBlankLines(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\n\(marker)\n", with: "\n\n")
            .replacingOccurrences(of: "\n\(marker)\n", with: "\n\n")
    }
}

private extension ParsedType {
    /// Annotation matching for values already flattened into the template context.
    static func isAnnotated(_ type: [String: Any], with annotation: String) -> Bool {
        let annotations = type["annotations"] as? [String: String] ?? [:]

        guard let equalsIndex = annotation.firstIndex(of: "=") else {
            return annotations[annotation] != nil
        }

        let key = annotation[annotation.startIndex ..< equalsIndex].trimmingCharacters(in: .whitespaces)
        let value = annotation[annotation.index(after: equalsIndex)...].trimmingCharacters(in: .whitespaces)
        return annotations[key] == value
    }
}
