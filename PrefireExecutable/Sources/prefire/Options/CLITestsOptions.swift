import Foundation

/// Raw CLI options for Tests command - no merging or resolution logic
struct CLITestsOptions {
    let target: String?
    let testTarget: String?
    let template: String?
    let sources: [String]
    let output: String?
    let testTargetPath: String?
    let cacheBasePath: String?
    let device: String?
    let osVersion: String?
}
