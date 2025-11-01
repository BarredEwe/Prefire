#if os(macOS)

import Foundation

let env = ProcessInfo.processInfo.environment
let bundleRel = "Binaries/PrefireBinary.artifactbundle"

func firstBinary(in base: URL) -> String? {
    let bundle = base.appendingPathComponent(bundleRel, isDirectory: true)
    guard let names = try? FileManager.default.contentsOfDirectory(atPath: bundle.path) else { return nil }
    for name in names {
        let bin = bundle.appendingPathComponent(name).appendingPathComponent("bin/prefire")
        if FileManager.default.isExecutableFile(atPath: bin.path) { return bin.path }
    }
    return nil
}

func findBinary() -> String? {
    if let override = env["PREFIRE_BINARY_PATH"], !override.isEmpty { return override }

    let exeBase = (0..<4).reduce(URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()) { $0.deletingLastPathComponent() }
    let srcBase = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let cwdBase = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

    return firstBinary(in: exeBase) ?? firstBinary(in: srcBase) ?? firstBinary(in: cwdBase)
}

guard let binaryPath = findBinary() else {
    FileHandle.standardError.write(Data("prefire: unable to locate PrefireBinary\n".utf8))
    exit(EXIT_FAILURE)
}

let process = Process()
process.executableURL = URL(fileURLWithPath: binaryPath)
process.arguments = Array(CommandLine.arguments.dropFirst())
process.standardInput = .standardInput
process.standardOutput = .standardOutput
process.standardError = .standardError

do {
    try process.run()
    process.waitUntilExit()
    exit(process.terminationStatus)
} catch {
    FileHandle.standardError.write(Data("prefire: failed to launch: \(error)\n".utf8))
    exit(EXIT_FAILURE)
}

#endif
