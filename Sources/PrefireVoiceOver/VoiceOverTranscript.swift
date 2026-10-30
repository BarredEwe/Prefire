#if os(iOS)
import ObjectiveC
import UIKit

/// Formats parsed elements in VoiceOver order, under UIKit views and announced containers.
public enum VoiceOverTranscript {
    /// An element VoiceOver focuses.
    public struct Element {
        /// Position in VoiceOver order.
        public var traversalIndex: Int
        /// The object that provides the element: a view, a `UIAccessibilityElement` or a node of SwiftUI.
        public var source: NSObject
        /// Label, value and traits, as VoiceOver reads them.
        public var spokenDescription: String
        public var hint: String?
        public var customActions: [String]
        public var customContent: [CustomContent]
        public var customRotors: [CustomRotor]
        public var language: String?

        public init(
            traversalIndex: Int,
            source: NSObject,
            spokenDescription: String,
            hint: String? = nil,
            customActions: [String] = [],
            customContent: [CustomContent] = [],
            customRotors: [CustomRotor] = [],
            language: String? = nil
        ) {
            self.traversalIndex = traversalIndex
            self.source = source
            self.spokenDescription = spokenDescription
            self.hint = hint
            self.customActions = customActions
            self.customContent = customContent
            self.customRotors = customRotors
            self.language = language
        }
    }

    /// Content VoiceOver reads with the element when it is important, and on request otherwise.
    public struct CustomContent {
        public var label: String
        public var value: String
        public var isImportant: Bool

        public init(label: String, value: String, isImportant: Bool = false) {
            self.label = label
            self.value = value
            self.isImportant = isImportant
        }
    }

    public struct CustomRotor {
        public var name: String
        /// How many results the rotor has.
        public var resultCount: Int

        public init(name: String, resultCount: Int) {
            self.name = name
            self.resultCount = resultCount
        }
    }

    /// The tree of `elements`, a line each, indented by two spaces a level.
    @MainActor
    static func text(of elements: [Element]) -> String {
        let elements = elements.sorted { $0.traversalIndex < $1.traversalIndex }
        var paths = elements.map { ancestors(of: $0.source) }

        // A view that is an element and holds other elements too is a node above its own phrase.
        let holders = Set(paths.flatMap(\.self).map(ObjectIdentifier.init))
        for (index, element) in elements.enumerated()
            where element.source is UIView && holders.contains(ObjectIdentifier(element.source)) {
            paths[index].append(element.source)
        }

        var lines: [String] = []
        var previous: [Node] = []
        for (element, path) in zip(elements, paths) {
            let nodes = path.flatMap(nodes(of:))
            let shared = zip(nodes, previous).prefix { $0 == $1 }.count
            for (depth, node) in nodes.enumerated().dropFirst(shared) {
                lines.append(indent(depth) + node.name)
            }
            previous = nodes

            let phrase = phrase(of: element)
            lines.append(indent(nodes.count) + (phrase.isEmpty ? "-" : "- " + phrase))
            lines += details(of: element).map { indent(nodes.count + 1) + $0 }
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Private

    /// A line of the tree: an object of the chain above an element, and what it is named.
    private struct Node: Equatable {
        let object: ObjectIdentifier
        let name: String
    }

    /// Objects above `source`, the root first: views up the `superview` chain, and before the first
    /// view, the `accessibilityContainer` chain of elements that are not views.
    @MainActor
    private static func ancestors(of source: NSObject) -> [NSObject] {
        var chain: [NSObject] = []
        var current = parent(of: source)
        while let object = current, chain.count < 200, !chain.contains(where: { $0 === object }) {
            chain.append(object)
            current = parent(of: object)
        }
        return chain.reversed()
    }

    @MainActor
    private static func parent(of object: NSObject) -> NSObject? {
        if let view = object as? UIView {
            return view.superview
        }
        if let element = object as? UIAccessibilityElement {
            return element.accessibilityContainer as? NSObject
        }
        // SwiftUI proxy objects can expose the selector without being UIAccessibilityElement.
        let key = "accessibilityContainer"
        guard object.responds(to: NSSelectorFromString(key)) else { return nil }
        return object.value(forKey: key) as? NSObject
    }

    /// The type of a view of the app, and the containers VoiceOver announces.
    @MainActor
    private static func nodes(of object: NSObject) -> [Node] {
        let id = ObjectIdentifier(object)
        var names: [String] = []

        if let view = object as? UIView {
            let name = appTypeName(of: view)
            if view.accessibilityViewIsModal {
                names.append((name ?? String(describing: type(of: view))) + " (modal)")
            } else if let name {
                names.append(name)
            }
        }

        if object.accessibilityTraits.contains(.tabBar) {
            names.append("[tab bar]")
        } else {
            switch object.accessibilityContainerType {
            case .list:
                names.append("[list]")
            case .dataTable:
                names.append("[table]")
            case .semanticGroup:
                if let label = object.accessibilityLabel, !label.isEmpty {
                    names.append("[group: \(label)]")
                }
            default:
                break
            }
        }

        return names.map { Node(object: id, name: $0) }
    }

    /// System classes are identified by their loaded image, including simulator runtime paths.
    static func appTypeName(of view: UIView) -> String? {
        guard let image = class_getImageName(type(of: view)),
              !String(cString: image).contains("/System/Library/") else { return nil }
        let context = #"\((unknown context|extension in) [^)]*\)\."#
        let name = String(reflecting: type(of: view))
            .replacingOccurrences(of: context, with: "", options: .regularExpression)
            .prefix { $0 != "<" }
        let typeName = name.split(separator: ".").dropFirst().joined(separator: ".")
        return typeName.isEmpty || typeName.hasPrefix("_") ? nil : typeName
    }

    /// Description, important custom content and hint, as VoiceOver reads them one after another.
    private static func phrase(of element: Element) -> String {
        let content = element.customContent.filter(\.isImportant).map(contentDescription)
        return ([element.spokenDescription] + content + [element.hint ?? ""])
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    @MainActor
    private static func details(of element: Element) -> [String] {
        var lines: [String] = []

        if !element.customActions.isEmpty {
            lines.append("actions: " + element.customActions.joined(separator: ", "))
        }

        let content = element.customContent.filter { !$0.isImportant }
        if !content.isEmpty {
            lines.append("custom content: " + content.map(contentDescription).joined(separator: "; "))
        }

        lines += element.customRotors.map { "rotor \"\($0.name)\": \($0.resultCount)" }

        let traits = element.source.accessibilityTraits
        let traitNames = [
            traits.contains(.allowsDirectInteraction) ? "direct interaction" : nil,
            traits.contains(.updatesFrequently) ? "updates frequently" : nil
        ].compactMap(\.self)
        if !traitNames.isEmpty {
            lines.append("traits: " + traitNames.joined(separator: ", "))
        }

        if let language = element.language, !language.isEmpty, !isAmbientLanguage(language) {
            lines.append("language: " + language)
        }
        return lines
    }

    /// Some SDK runtimes autofill the ambient UI language into every element (iOS 18 attaches
    /// "en-Latn-US" on an en-US system) and others leave it empty; the language detail is
    /// reserved for elements that actually speak something else.
    private static func isAmbientLanguage(_ language: String) -> Bool {
        let element = Locale(identifier: language)
        let ambient = Locale.current
        guard let ambientCode = ambient.languageCode else { return false }
        return element.languageCode == ambientCode && element.regionCode == ambient.regionCode
    }

    private static func contentDescription(_ content: CustomContent) -> String {
        content.label.isEmpty ? content.value : "\(content.label): \(content.value)"
    }

    private static func indent(_ depth: Int) -> String {
        String(repeating: "  ", count: depth)
    }
}

#endif
