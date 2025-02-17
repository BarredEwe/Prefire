import Foundation

struct RawPreviewModel {
    var displayName: String
    var traits: String
    var body: String
    var snapshotSettings: String?
}

extension RawPreviewModel {
    private enum Markers {
        static let previewMacro = "#Preview"
        static let traits = "traits: "
        static let snasphotSettings = ".snapshot("
    }

    private enum Constants {
        static let defaultTrait = ".device"
    }

    /// Initialization from the macro Preview body
    /// - Parameters:
    ///   - macroBody: Preview View body
    ///   - filename: File name in which the macro was found
    ///   - lineSymbol: The line separator symbol
    init?(from macroBody: String, filename: String, lineSymbol: String = "") {
        let lines = macroBody.split(separator: "\n", omittingEmptySubsequences: false)
        guard let firstLine = lines.first else { return nil }
        
        // Define displayName by splitting the first line by "
        let parts = firstLine.split(separator: "\"")
        if let namePart = parts.first(where: { !$0.contains(Markers.previewMacro) }) {
            self.displayName = String(namePart)
        } else {
            self.displayName = filename
        }
        
        // Retrieve traits using a range finder
        var previewTrait: String?
        if let range = firstLine.range(of: Markers.traits) {
            let substring = firstLine[range.upperBound...]
            if let endIndex = substring.firstIndex(of: ")") {
                previewTrait = String(substring[..<endIndex])
            }
        }
        self.traits = previewTrait ?? Constants.defaultTrait
        
        // Search for the line with snapshot settings
        if let configLine = lines.first(where: { $0.contains(Markers.snasphotSettings) }) {
            self.snapshotSettings = configLine.trimmingCharacters(in: .whitespaces)
        } else {
            self.snapshotSettings = nil
        }
        
        // Forming the Preview body: remove the first and last two lines
        let bodyLines = lines.dropFirst().dropLast(2)
        self.body = bodyLines.map { lineSymbol + $0 }.joined(separator: "\n")
    }
}

extension RawPreviewModel {
    var previewModel: String {
        """
                    PreviewModel(
                        content: {
        \(body)
                        },
                        name: \"\(displayName)\",
                        type: \(traits == ".device" ? ".screen" : ".component")
                    ),
        """
    }
}
