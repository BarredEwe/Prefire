#if os(macOS)

import Foundation

enum BinaryLocator {
    static let bundleName = "PrefireBinary.artifactbundle"

    static func firstExecutable(in bundleURL: URL) -> String? {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: bundleURL.path)) ?? []
        for name in names {
            let bin = bundleURL.appendingPathComponent(name).appendingPathComponent("bin/prefire")
            if FileManager.default.isExecutableFile(atPath: bin.path) { return bin.path }
        }
        return nil
    }

    static func candidateBundleURLs(resourceURL: URL? = Bundle.module.resourceURL, cwd: String = FileManager.default.currentDirectoryPath) -> [URL] {
        var urls: [URL] = []
        if let resourceURL {
            urls.append(resourceURL.appendingPathComponent(bundleName, isDirectory: true))
        }
        urls.append(URL(fileURLWithPath: cwd).appendingPathComponent("Binaries").appendingPathComponent(bundleName, isDirectory: true))
        return urls
    }

    static func findBinary(env: [String: String] = ProcessInfo.processInfo.environment, resourceURL: URL? = Bundle.module.resourceURL, cwd: String = FileManager.default.currentDirectoryPath) -> String? {
        if let override = env["PREFIRE_BINARY_PATH"], !override.isEmpty { return override }
        for url in candidateBundleURLs(resourceURL: resourceURL, cwd: cwd) {
            if let bin = firstExecutable(in: url) { return bin }
        }
        return nil
    }
}

#endif
