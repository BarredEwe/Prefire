import Foundation

struct RawPreviewModel {
    var displayName: String
    var traits: String
    var body: String
    var properties: String?
    var snapshotSettings: String?
    
    var isScreen: Bool {
        traits == Constants.defaultTrait
    }
}

extension RawPreviewModel {
    private enum Markers {
        static let previewMacro = "#Preview"
        static let traits = "traits: "
        static let snasphotSettings = ".snapshot("
        static let previewable = "@Previewable"
    }

    private enum Constants {
        static let defaultTrait = ".device"
    }

    /// Initialization from the macro Preview body
    /// - Parameters:
    ///   - macroBody: Preview View body
    ///   - filename: File name in which the macro was found
    init?(from macroBody: String, filename: String) {
        var lines = macroBody.split(separator: "\n", omittingEmptySubsequences: false).dropLast(2)
        let firstLine = lines.removeFirst()
        
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
        
        
        for (index, line) in lines.enumerated() {
            // Search for the line with snapshot settings
            if snapshotSettings == nil, line.contains(Markers.snasphotSettings) {
                self.snapshotSettings = line.trimmingCharacters(in: .whitespaces)
            } else if line.contains(Markers.previewable) {
                lines.remove(at: index + 1)
                if self.properties == nil {
                    self.properties = String(line.replacing("\(Markers.previewable) ", with: ""))
                } else {
                    self.properties! += "\n" + String(line.replacing(Markers.previewable, with: ""))
                }
            }
        }
        
        self.body = lines.joined(separator: "\n")
    }
}

extension RawPreviewModel {
    var previewWrapper: String {
        """
            struct PreviewWrapper\(displayName): SwiftUI.View {
                \(properties ?? "")
                    var body: some SwiftUI.View {
        \(body.ident(12))
                    }
                }
        """
    }

    var previewModel: String {
        """
                    PreviewModel(
                        content: {
        \(properties == nil ? body.ident(16) : "                    PreviewWrapper\(displayName)()")
                        },
                        name: \"\(displayName)\",
                        type: \(traits == ".device" ? ".screen" : ".component")
                    ),
        """
    }
}
