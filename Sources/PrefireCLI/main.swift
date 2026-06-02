#if os(macOS)

import Foundation

let env = ProcessInfo.processInfo.environment
let bundleName = "PrefireBinary.artifactbundle"

func firstBinary(in bundleURL: URL) -> String? {
    let names = (try? FileManager.default.contentsOfDirectory(atPath: bundleURL.path)) ?? []
    for name in names.sorted().reversed() {
        let bin = bundleURL.appendingPathComponent(name).appendingPathComponent("bin/prefire")
        if FileManager.default.isExecutableFile(atPath: bin.path) { return bin.path }
    }
    return nil
}

func findBinary() -> String? {
    if let override = env["PREFIRE_BINARY_PATH"], !override.isEmpty { return override }

    if let resourceURL = Bundle.module.resourceURL {
        let bundleURL = resourceURL.appendingPathComponent(bundleName, isDirectory: true)
        if let bin = firstBinary(in: bundleURL) { return bin }
    }

    let cwdBundle = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("Binaries").appendingPathComponent(bundleName, isDirectory: true)
    return firstBinary(in: cwdBundle)
}

guard let binaryPath = findBinary() else {
    FileHandle.standardError.write(Data("prefire: unable to locate PrefireBinary\n".utf8))
    exit(EXIT_FAILURE)
}

let process = Process()
process.executableURL = URL(fileURLWithPath: binaryPath)
process.arguments = Array(CommandLine.arguments.dropFirst())
process.standardInput = FileHandle.standardInput
process.standardOutput = FileHandle.standardOutput
process.standardError = FileHandle.standardError

do {
    try process.run()
    process.waitUntilExit()
    exit(process.terminationStatus)
} catch {
    FileHandle.standardError.write(Data("prefire: failed to launch: \(error)\n".utf8))
    exit(EXIT_FAILURE)
}

#endif
