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
    /// - Returns: A dictionary containing the preview bodies for the sources, with file names as keys and preview bodies as values
    static func loadRawPreviewBodies(for sources: [String], defaultEnabled: Bool) -> [String: String]? {
        var previewBodyDictionary = [String: String]()

        for url in sources.compactMap(URL.init(string:)) {
            do {
                guard !url.isDirectory else {
                    let urls = FileManager.default.listFiles(atPath: url.path())
                    let bodies = loadRawPreviewBodies(for: urls, defaultEnabled: defaultEnabled) ?? [:]
                    previewBodyDictionary.merge(bodies) { _, new in new }
                    continue
                }

                let content = try String(contentsOfFile: url.path)
                guard !content.isEmpty, content.contains(Constants.previewMarker) else { continue }

                if let previewBodies = previewBodies(from: content, defaultEnabled: defaultEnabled) {
                    let fileName = url.fileName
                    previewBodies.enumerated().forEach { index, previewBody in
                        previewBodyDictionary["\(fileName)_\(index)"] = previewBody
                    }
                }
            } catch {
                Logger.print("⚠️ Cannot load file with Preview macro at path: \(url.path)")
            }
        }

        return previewBodyDictionary.isEmpty ? nil : previewBodyDictionary
    }

    /// Extract the preview body using the passed content
    ///
    /// - Parameters:
    ///   - content: File content
    ///   - defaultEnabled: Whether automatic view inclusion should be allowed. Default value is true.
    /// - Returns: An array representing the results of the macro preview without the initial `#Preview` and final `}`.
    static func previewBodies(from content: String, defaultEnabled: Bool) -> [String]? {
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

            guard previewWasFound else { continue }

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

        return previewBodies.isEmpty ? nil : previewBodies
    }
}
