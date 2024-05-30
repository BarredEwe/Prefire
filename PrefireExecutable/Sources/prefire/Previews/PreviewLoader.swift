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

    /// Attempts to locate raw preview bodies within the specified sources string and returns them as an array of Strings.
    /// - Parameters:
    ///   - sources: Paths to a source swift files or directories.
    ///   - defaultEnabled: Whether automatic view inclusion should be allowed. Default value is true.
    /// - Returns: Array of Strings
    static func loadRawPreviewBodies(for sources: [String], defaultEnabled: Bool) -> [String]? {
        var previewMacroBodies = [String]()
        let urls = sources.compactMap { URL(string: $0) }

        for url in urls {
            guard !url.pathExtension.isEmpty else {
                let urls = FileManager.default.listFiles(atPath: url.path())
                let bodies = loadRawPreviewBodies(for: urls, defaultEnabled: defaultEnabled) ?? []
                previewMacroBodies.append(contentsOf: bodies)
                continue
            }

            guard let content = try? String(contentsOfFile: url.path), !content.isEmpty else {
                Logger.print("⚠️ Cannot load file with Preview macro at path: \(url.path)")
                continue
            }

            guard content.contains(Constants.previewMarker) else { continue }

            let previewBodies = previewBodies(from: content, defaultEnabled: defaultEnabled)

            if !previewBodies.isEmpty {
                previewMacroBodies.append(contentsOf: previewBodies)
            }
        }

        return previewMacroBodies.isEmpty ? nil : previewMacroBodies
    }

    /// Extract the preview body using the passed content
    ///
    /// - Parameters:
    ///   - content: File content
    ///   - defaultEnabled: Whether automatic view inclusion should be allowed. Default value is true.
    /// - Returns: An array representing the results of the macro preview without the initial `#Preview` and final `}`.
    static func previewBodies(from content: String, defaultEnabled: Bool) -> [String] {
        var previewBodies: [String] = []

        let lines = content.components(separatedBy: .newlines)

        var result = ""
        var previewWasFound = false
        var viewMustBeLoaded = defaultEnabled

        var openingBraceCount = 0
        var closingBraceCount = 0

        for line in lines {
            if line.hasPrefix(Constants.previewMarker) {
                previewWasFound = true
            }

            if previewWasFound {
                openingBraceCount += line.filter { $0 == Constants.openingBrace }.count
                closingBraceCount += line.filter { $0 == Constants.closingBrace }.count

                if defaultEnabled {
                    if line.hasSuffix(Constants.prefireDisableMarker) {
                        viewMustBeLoaded = false
                    }
                } else if !viewMustBeLoaded {
                    viewMustBeLoaded = line.hasSuffix(Constants.prefireEnabledMarker)
                }

                result += (line + "\n")

                if openingBraceCount == closingBraceCount {
                    if !result.isEmpty, viewMustBeLoaded {
                        previewBodies.append(result)
                    }

                    result = ""
                    previewWasFound = false
                    viewMustBeLoaded = defaultEnabled
                    openingBraceCount = .zero
                    closingBraceCount = .zero
                }
            }
        }

        return previewBodies
    }
}
