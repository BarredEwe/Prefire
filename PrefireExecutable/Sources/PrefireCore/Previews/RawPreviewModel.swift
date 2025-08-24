import Foundation

struct RawPreviewModel {
    var displayName: String
    var traits: [String]
    var body: String
    var properties: String?

    var isScreen: Bool {
        traits.contains(Constants.defaultTrait)
    }
}

extension RawPreviewModel {
    private enum Markers {
        static let previewMacro = "#Preview"
        static let traits = "traits: "
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
        guard !macroBody.isEmpty else { return nil }

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
            let endIndex = Self.findTraitsEndIndex(in: substring)
            if let endIndex = endIndex {
                previewTrait = String(substring[..<endIndex])
            }
        }

        // Traits can be functions like .myTraitt("one", 2), .device
        // We can have both at the same time separated by comma
        self.traits = Self.parseTraits(from: previewTrait)

        for (index, line) in lines.enumerated() {
            // Search for the line with `@Previewable` macro
            if line.contains(Markers.previewable) {
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
    
    /// Parse traits from the raw trait string
    /// Handles single traits, comma-separated traits, and function-style traits
    private static func parseTraits(from rawTraits: String?) -> [String] {
        guard let rawTraits = rawTraits?.trimmingCharacters(in: .whitespacesAndNewlines), 
              !rawTraits.isEmpty else {
            return [Constants.defaultTrait]
        }
        
        // Pre-allocate array with estimated capacity for better performance
        var traits: [String] = []
        traits.reserveCapacity(4) // Most common case: 1-3 traits

        let startIndex = rawTraits.startIndex
        let endIndex = rawTraits.endIndex
        var currentStart = startIndex
        var currentIndex = startIndex
        var parenthesesDepth = 0
        var insideQuotes = false
        var quoteChar: Character?
        
        while currentIndex < endIndex {
            let char = rawTraits[currentIndex]
            
            switch char {
            case "\"", "'":
                if !insideQuotes {
                    insideQuotes = true
                    quoteChar = char
                } else if char == quoteChar {
                    insideQuotes = false
                    quoteChar = nil
                }
            case "(":
                if !insideQuotes {
                    parenthesesDepth += 1
                }
            case ")":
                if !insideQuotes {
                    parenthesesDepth -= 1
                }
            case ",":
                if !insideQuotes && parenthesesDepth == 0 {
                    // This comma is a trait separator
                    let traitSubstring = rawTraits[currentStart..<currentIndex]
                    let trimmedTrait = traitSubstring.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedTrait.isEmpty {
                        traits.append(String(trimmedTrait))
                    }
                    currentStart = rawTraits.index(after: currentIndex)
                }
            default:
                break
            }
            
            currentIndex = rawTraits.index(after: currentIndex)
        }
        
        // Add the last trait
        let lastTraitSubstring = rawTraits[currentStart..<endIndex]
        let trimmedLastTrait = lastTraitSubstring.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedLastTrait.isEmpty {
            traits.append(String(trimmedLastTrait))
        }
        
        return traits.isEmpty ? [Constants.defaultTrait] : traits
    }
    
    /// Find the correct end index for traits, respecting parentheses balance
    private static func findTraitsEndIndex(in substring: Substring) -> String.Index? {
        var parenthesesDepth = 0
        var insideQuotes = false
        var quoteChar: Character?
        var currentIndex = substring.startIndex
        let endIndex = substring.endIndex
        
        while currentIndex < endIndex {
            let char = substring[currentIndex]
            
            switch char {
            case "\"", "'":
                if !insideQuotes {
                    insideQuotes = true
                    quoteChar = char
                } else if char == quoteChar {
                    insideQuotes = false
                    quoteChar = nil
                }
            case "(":
                if !insideQuotes {
                    parenthesesDepth += 1
                }
            case ")":
                if !insideQuotes {
                    if parenthesesDepth == 0 {
                        // This is the closing parenthesis of the #Preview call
                        return currentIndex
                    }
                    parenthesesDepth -= 1
                }
            default:
                break
            }
            
            currentIndex = substring.index(after: currentIndex)
        }
        
        // If we didn't find a balanced closing parenthesis, return nil
        return nil
    }
}

extension RawPreviewModel {
    private static let funcCharacterSet = CharacterSet(arrayLiteral: "_").inverted.intersection(.alphanumerics.inverted)

    var componentTestName: String {
        displayName.components(separatedBy: Self.funcCharacterSet).joined()
    }

    func makeStencilDict() -> [String: Any?] {
        return [
            "displayName": displayName,
            "componentTestName": componentTestName,
            "isScreen": isScreen,
            "body": body,
            "properties": properties,
            "traits": traits
        ].filter({ $0.value != nil })
    }
}
