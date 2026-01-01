import Foundation

/// Simplify and improve the process of locating and parsing generated preview code for Swift projects.
enum PreviewLoader {
    enum Constants {
        static let previewMarker = "#Preview"
        static let prefireDisableMarker = ".prefireIgnored()"
        static let prefireEnabledMarker = ".prefireEnabled()"
        static let openingBrace: Character = "{"
        static let closingBrace: Character = "}"
    }

    /// Extract the preview body using the passed content
    ///
    /// - Parameters:
    ///   - content: File content
    ///   - defaultEnabled: Whether automatic view inclusion should be allowed. Default value is true.
    /// - Returns: An array representing the results of the macro preview without the initial `#Preview` and final `}`.
    static func previewBodies(from content: String, defaultEnabled: Bool) -> [String]? {
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
        var previewBodies: [String] = []

        var currentBody: String = ""
        var previewWasFound = false
        var viewMustBeLoaded = defaultEnabled
        var braceBalance: Int? = nil

        for line in lines {
            if line.hasPrefix(Constants.previewMarker) {
                previewWasFound = true
                currentBody = ""
                braceBalance = nil
            }

            guard previewWasFound else { continue }

            let braceChange = line.reduce(0) { (count, char) in
                if char == Constants.openingBrace {
                    return count + 1
                } else if char == Constants.closingBrace {
                    return count - 1
                }
                return count
            }

            if braceChange != 0 || braceBalance != nil {
                braceBalance = (braceBalance ?? 0) + braceChange
            }

            if defaultEnabled {
                if line.contains(Constants.prefireDisableMarker) {
                    viewMustBeLoaded = false
                }
            } else if !viewMustBeLoaded {
                viewMustBeLoaded = line.contains(Constants.prefireEnabledMarker)
            }

            currentBody.append(String(line) + "\n")

            if braceBalance == 0 {
                if !currentBody.isEmpty, viewMustBeLoaded {
                    previewBodies.append(currentBody)
                }

                previewWasFound = false
                viewMustBeLoaded = defaultEnabled
            }
        }

        return previewBodies.isEmpty ? nil : previewBodies
    }
}
