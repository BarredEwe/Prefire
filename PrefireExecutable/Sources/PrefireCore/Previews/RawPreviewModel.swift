import Foundation

struct RawPreviewModel: Codable, Equatable {
    var displayName: String
    var traits: [String]
    /// `CGSize` expression from `.fixedLayout(width:height:)`, or `nil` when the trait is absent.
    var fixedLayoutSize: String?
    var body: String
    var properties: String?
    var arguments: String?
    var argumentPattern: String?

    var isScreen: Bool {
        traits.contains(Constants.defaultTrait)
    }

    var hasArguments: Bool {
        arguments != nil && argumentPattern != nil
    }
}

extension RawPreviewModel {
    private enum Constants {
        static let defaultTrait = ".device"
    }
    private static let funcCharacterSet = CharacterSet(arrayLiteral: "_").inverted.intersection(.alphanumerics.inverted)

    var componentTestName: String {
        displayName.components(separatedBy: Self.funcCharacterSet).joined()
    }

    func makeStencilDict() -> [String: Any?] {
        return [
            "displayName": displayName,
            "componentTestName": componentTestName,
            "isScreen": isScreen,
            "fixedLayoutSize": fixedLayoutSize,
            "body": body,
            "properties": properties,
            "arguments": arguments,
            "argumentPattern": argumentPattern,
            "hasArguments": hasArguments,
            "traits": traits
        ].filter({ $0.value != nil })
    }
}
