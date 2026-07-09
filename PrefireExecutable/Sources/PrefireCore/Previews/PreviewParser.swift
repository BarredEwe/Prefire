import SwiftSyntax

final class PreviewParser: SyntaxVisitor {
    private(set) var body: String?
    private(set) var properties: [String] = []
    private(set) var displayName: String?
    private(set) var traits: [String]?
    private(set) var arguments: String?
    private(set) var argumentPattern: String?
    
    enum Constants {
        static let previewable = "Previewable"
        static let previewMacro = "Preview"
    }
    
    init() {
        super.init(viewMode: .sourceAccurate)
    }

    var propertiesSource: String? {
        guard let firstProperty = properties.first else { return nil }

        return properties.dropFirst().reduce(firstProperty) {
            "\($0)\n\($1)"
        }
    }

    override func visit(_ node: MacroExpansionExprSyntax) -> SyntaxVisitorContinueKind {
        guard node.macroName.text == Constants.previewMacro else { return .visitChildren }

        collectMacroData(arguments: node.arguments, trailingClosure: node.trailingClosure)

        return .visitChildren
    }

    override func visit(_ node: MacroExpansionDeclSyntax) -> SyntaxVisitorContinueKind {
        guard node.macroName.text == Constants.previewMacro else { return .visitChildren }

        collectMacroData(arguments: node.arguments, trailingClosure: node.trailingClosure)

        return .visitChildren
    }

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        guard node.attributes.contain(matchingName: Constants.previewable) else {
            appendItemToBody(node)
            return .skipChildren
        }
        
        var resultVariable = node
        resultVariable.attributes = node.attributes.remove(matchingName: Constants.previewable)
        properties.append("\(resultVariable.trimmed)")
        return .skipChildren
    }
    
    override func visit(_ node: CodeBlockItemSyntax) -> SyntaxVisitorContinueKind {
        if node.item.is(VariableDeclSyntax.self) || node.item.is(MacroExpansionExprSyntax.self) {
            return .visitChildren
        }
        
        appendItemToBody(node)
        return .skipChildren
    }
}

private extension PreviewParser {
    func appendItemToBody(_ node: some SyntaxProtocol) {
        if let body {
            self.body = "\(body)\n\(node.trimmed)"
        } else {
            body = "\(node.trimmed)"
        }
    }

    func collectMacroData(arguments macroArgumentList: LabeledExprListSyntax, trailingClosure: ClosureExprSyntax?) {
        let macroArguments = Array(macroArgumentList)

        if let firstArgument = macroArguments.first,
           firstArgument.label == nil {
            displayName = Self.stringLiteralValue(from: firstArgument.expression)
        }

        traits = Self.traits(from: macroArguments)

        arguments = macroArguments.first(where: { $0.label?.text == "arguments" }).map {
            "\($0.expression.trimmed)"
        }

        argumentPattern = trailingClosure.flatMap(Self.argumentPattern)
    }

    static func stringLiteralValue(from expression: ExprSyntax) -> String? {
        guard let literal = expression.as(StringLiteralExprSyntax.self) else { return nil }

        let segments = literal.segments.compactMap { $0.as(StringSegmentSyntax.self)?.content.text }
        guard segments.count == literal.segments.count else { return nil }

        return segments.joined()
    }

    static func traits(from arguments: [LabeledExprSyntax]) -> [String]? {
        guard let traitsIndex = arguments.firstIndex(where: { $0.label?.text == "traits" }) else {
            return nil
        }

        var traits = ["\(arguments[traitsIndex].expression.trimmed)"]
        var index = arguments.index(after: traitsIndex)

        while index < arguments.endIndex, arguments[index].label == nil {
            traits.append("\(arguments[index].expression.trimmed)")
            index = arguments.index(after: index)
        }

        return traits
    }

    static func argumentPattern(from closure: ClosureExprSyntax) -> String? {
        guard let parameterClause = closure.signature?.parameterClause else { return nil }

        let names: [String]
        switch parameterClause {
        case .simpleInput(let parameters):
            names = parameters.map { $0.name.text }
        case .parameterClause(let parameterClause):
            names = parameterClause.parameters.map { ($0.secondName ?? $0.firstName).text }
        }

        let filteredNames = names.filter { !$0.isEmpty && $0 != "_" }
        guard !filteredNames.isEmpty else { return nil }

        if filteredNames.count == 1 {
            return filteredNames[0]
        } else {
            return "(\(filteredNames.joined(separator: ", ")))"
        }
    }
}

private extension AttributeListSyntax {
    func contain(matchingName: String) -> Bool {
        self.contains {
            guard let attribute = $0.as(AttributeSyntax.self),
                  let attributeName = attribute.attributeName.as(IdentifierTypeSyntax.self) else { return false }
            return attributeName.name.text == matchingName
        }
    }
    
    func remove(matchingName: String) -> Self {
        self.filter {
            guard let attribute = $0.as(AttributeSyntax.self),
                  let attributeName = attribute.attributeName.as(IdentifierTypeSyntax.self) else { return true }
            return attributeName.name.text != matchingName
        }
    }
}
