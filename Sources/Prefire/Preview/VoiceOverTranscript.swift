#if os(iOS) || os(tvOS)
import UIKit

/// What VoiceOver reads on a screen, as a tree of the views of the app that hold the elements.
///
/// Takes the elements an accessibility parser found, such as `AccessibilityHierarchyParser` of
/// AccessibilitySnapshot, so the library does not depend on one:
///
/// ```text
/// SettingsView
///   [list]
///     SettingsRow
///       - Notifications. Switch Button. On.
///     SettingsRow
///       - Language. Button. English.
/// ```
///
/// Elements are listed in VoiceOver order as `- <phrase>`, under the views that hold them and the
/// containers VoiceOver announces (`[list]`, `[tab bar]`, `[table]`, `[group: <label>]`). A view is
/// a node when its type comes from a module other than the system's or Prefire's, third-party
/// packages included. A node shared with the element before is not repeated. What VoiceOver tells
/// about an element on request follows on indented lines.
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
    public static func text(of elements: [Element]) -> String {
        let elements = elements.sorted { $0.traversalIndex < $1.traversalIndex }
        var paths = elements.map { ancestors(of: $0.source) }

        // A view that is an element and holds other elements too is a node above its own phrase.
        let holders = Set(paths.flatMap { $0 }.map(ObjectIdentifier.init))
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

            let phrase = self.phrase(of: element)
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
        // Declared on `NSObject` in Objective-C only, so it is read with key-value coding.
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

    /// Name of the type of `view` without its module, or `nil` for a type of the system or Prefire,
    /// and for an Objective-C class, which has no module.
    /// A hosting view is named after the view it hosts.
    static func appTypeName(of view: UIView) -> String? {
        appTypeName(String(reflecting: type(of: view)))
    }

    /// `appTypeName(of:)` of a type named like `String(reflecting:)` names it.
    static func appTypeName(_ reflected: String) -> String? {
        let context = #"\((unknown context|extension in) [^)]*\)\."#
        let name = reflected.replacingOccurrences(of: context, with: "", options: .regularExpression)

        let hostingPrefix = "SwiftUI._UIHostingView<"
        if name.hasPrefix(hostingPrefix), name.hasSuffix(">") {
            return appTypeName(String(name.dropFirst(hostingPrefix.count).dropLast()))
        }

        let withoutGenerics = name.prefix { $0 != "<" }
        guard let dot = withoutGenerics.firstIndex(of: ".") else { return nil }

        let module = withoutGenerics[..<dot]
        let typeName = String(withoutGenerics[withoutGenerics.index(after: dot)...])
        guard !systemModules.contains(String(module)), !typeName.isEmpty, !typeName.hasPrefix("_") else { return nil }
        return typeName
    }

    private static let systemModules: Set<String> = [
        "Swift", "SwiftUI", "SwiftUICore", "UIKit", "Foundation", "Prefire"
    ]

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
        ].compactMap { $0 }
        if !traitNames.isEmpty {
            lines.append("traits: " + traitNames.joined(separator: ", "))
        }

        if let language = element.language, !language.isEmpty {
            lines.append("language: " + language)
        }
        return lines
    }

    private static func contentDescription(_ content: CustomContent) -> String {
        content.label.isEmpty ? content.value : "\(content.label): \(content.value)"
    }

    private static func indent(_ depth: Int) -> String {
        String(repeating: "  ", count: depth)
    }
}

#if canImport(XCTest)
extension PrefireSnapshotCapture {
    /// What `read` makes of `accessibilityController()` hosted in a window, once it stops changing.
    ///
    /// Renders the preview anew like `accessibilityController()`, waits `delay`, then reads it every
    /// `SnapshotWaiter.pollInterval` (50 ms) until two reads in a row agree, since SwiftUI may build its
    /// accessibility tree a few passes of the run loop after the first layout.
    ///
    /// - Parameters:
    ///   - timeout: How long to wait for two reads to agree after `delay`. The generated tests pass
    ///              `snapshot_wait_timeout`.
    ///   - read: Reads the hosted view, for example parses its accessibility hierarchy.
    /// - Throws: `SnapshotWaitTimeout` when the reads kept changing for `timeout`, rather than
    ///           returning one of them, which would be recorded as a partial reference.
    @MainActor
    public func readVoiceOver<Value: Equatable>(
        timeout: TimeInterval = SnapshotWaitDefaults().timeout,
        _ read: (UIView) -> Value
    ) throws(SnapshotWaitTimeout) -> Value {
        let controller = accessibilityController()
        let window = UIWindow(frame: controller.view.frame)
        window.rootViewController = controller
        window.isHidden = false
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        controller.view.layoutIfNeeded()
        SnapshotWaiter.spinRunLoop(for: delay)

        let deadline = SnapshotWaiter.now + max(timeout, 0)
        var last = read(controller.view)
        while SnapshotWaiter.now < deadline {
            SnapshotWaiter.spinRunLoop(for: SnapshotWaiter.pollInterval)
            controller.view.layoutIfNeeded()

            let current = read(controller.view)
            if current == last {
                return current
            }
            last = current
        }
        throw SnapshotWaitTimeout(message: """
        Prefire: what VoiceOver reads in "\(name)" kept changing for \(String(format: "%g", timeout))s. \
        Raise `snapshot_wait_timeout`, or check that the preview stops changing.
        """)
    }
}
#endif
#endif
