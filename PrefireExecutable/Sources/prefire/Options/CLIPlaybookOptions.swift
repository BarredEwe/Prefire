import Foundation

/// Raw CLI options for Playbook command - no merging or resolution logic
struct CLIPlaybookOptions {
    let targetPath: String?
    let template: String?
    let sources: [String]
    let output: String?
    let cacheBasePath: String?
}
