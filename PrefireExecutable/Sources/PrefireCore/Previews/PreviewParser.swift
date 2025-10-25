import SwiftSyntax

final class PreviewParser: SyntaxVisitor {
    private(set) var body: String?
    private(set) var properties: [String] = []
    
    enum Constants {
        static let previewable = "Previewable"
    }
    
    init() {
        super.init(viewMode: .sourceAccurate)
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
