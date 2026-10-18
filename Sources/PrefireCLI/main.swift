#if os(macOS)

import Foundation

guard let binaryPath = BinaryLocator.findBinary() else {
    let checked = BinaryLocator.candidateBundleURLs().map(\.path).joined(separator: "\n  ")
    FileHandle.standardError.write(Data("prefire: unable to locate PrefireBinary. Checked:\n  \(checked)\n".utf8))
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
