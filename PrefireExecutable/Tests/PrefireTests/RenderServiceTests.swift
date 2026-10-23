import Foundation
@testable import PrefireCore
import XCTest

final class RenderServiceTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("RenderServiceTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private let catalog = [
        PreviewEntry(name: "Button", kind: .macro, file: "/App/Button.swift", line: 10, testClass: "PreviewTests", testMethod: "test_Button_Preview", isScreen: false),
        PreviewEntry(name: "Button-Row", kind: .macro, file: "/App/Button.swift", line: 20, testClass: "PreviewTests", testMethod: "test_ButtonRow_Preview", isScreen: false),
        PreviewEntry(name: "Card_Previews", kind: .provider, file: "/App/Card.swift", line: 5, testClass: "PreviewTests", testMethod: "test_card", isScreen: false),
        PreviewEntry(name: "Login", kind: .macro, file: "/App/Login.swift", line: 3, testClass: "LoginTests", testMethod: "test_Login_Preview", isScreen: true),
    ]

    // MARK: - xcodebuild

    func test_xcodebuildArguments() {
        let service = RenderService(configuration: RenderConfiguration(
            scheme: "App",
            workspace: "App.xcworkspace",
            destination: "platform=iOS Simulator,name=iPhone 16",
            outputDirectory: directory
        ))

        XCTAssertEqual(service.xcodebuildArguments(onlyTesting: ["AppTests/PreviewTests/test_Button_Preview"]), [
            "xcodebuild", "test", "-scheme", "App", "-workspace", "App.xcworkspace",
            "-destination", "platform=iOS Simulator,name=iPhone 16",
            "-parallel-testing-enabled", "NO",
            "-only-testing:AppTests/PreviewTests/test_Button_Preview",
        ])
    }

    func test_xcodebuildArguments_withProject() {
        let service = RenderService(configuration: RenderConfiguration(scheme: "App", project: "App.xcodeproj", outputDirectory: directory))

        XCTAssertEqual(Array(service.xcodebuildArguments(onlyTesting: []).prefix(6)), ["xcodebuild", "test", "-scheme", "App", "-project", "App.xcodeproj"])
    }

    func test_environment_passesOptionsToTheTestRunner() throws {
        let service = RenderService(configuration: RenderConfiguration(scheme: "App", outputDirectory: directory))
        let options = RenderOptions(directory: "/out", runID: "run", previews: ["Button"], colorScheme: "dark")

        let environment = try service.environment(for: options, base: ["PATH": "/usr/bin"])

        XCTAssertEqual(environment["PATH"], "/usr/bin")
        let json = try XCTUnwrap(environment["TEST_RUNNER_PREFIRE_RENDER"])
        XCTAssertEqual(environment["PREFIRE_RENDER"], json)
        XCTAssertEqual(try JSONDecoder().decode(RenderOptions.self, from: Data(json.utf8)), options)
    }

    // MARK: - Plan

    func test_plan_runsOnlyTheTestsOfThePreviews() {
        let plan = RenderService.plan(for: RenderRequest(previews: ["Button-1-primary", "Login", "Button"]), catalog: catalog, testTarget: "AppTests")

        XCTAssertEqual(plan.onlyTesting, ["AppTests/PreviewTests/test_Button_Preview", "AppTests/LoginTests/test_Login_Preview"])
        XCTAssertEqual(plan.runtimeFilter, ["Button-1-primary", "Login", "Button"])
    }

    func test_plan_prefersTheLongestMatchingName() {
        let plan = RenderService.plan(for: RenderRequest(previews: ["Button-Row"]), catalog: catalog, testTarget: "AppTests")

        XCTAssertEqual(plan.onlyTesting, ["AppTests/PreviewTests/test_ButtonRow_Preview"])
    }

    func test_plan_doesNotFilterByProviderTypeNames() {
        let plan = RenderService.plan(for: RenderRequest(previews: ["Card_Previews", "Login"]), catalog: catalog, testTarget: "AppTests")

        XCTAssertEqual(plan.onlyTesting, ["AppTests/PreviewTests/test_card", "AppTests/LoginTests/test_Login_Preview"])
        XCTAssertEqual(plan.runtimeFilter, [])
    }

    func test_plan_runsTheWholeTarget_whenANameIsNotFound() {
        let plan = RenderService.plan(for: RenderRequest(previews: ["Button", "Unknown"]), catalog: catalog, testTarget: "AppTests")

        XCTAssertEqual(plan, RenderService.Plan(onlyTesting: ["AppTests"], runtimeFilter: ["Button", "Unknown"]))
    }

    func test_plan_runsTheTarget_whenNoPreviewsAreAskedFor() {
        XCTAssertEqual(
            RenderService.plan(for: RenderRequest(), catalog: catalog, testTarget: "AppTests"),
            RenderService.Plan(onlyTesting: ["AppTests"], runtimeFilter: [])
        )
    }

    func test_plan_filtersAtRuntime_withoutATestTarget() {
        XCTAssertEqual(
            RenderService.plan(for: RenderRequest(previews: ["Button"]), catalog: catalog, testTarget: nil),
            RenderService.Plan(onlyTesting: [], runtimeFilter: ["Button"])
        )
    }

    // MARK: - Records

    func test_collect_keepsRecordsOfTheRunInSourceOrder_andRemovesStaleOnes() throws {
        try write(RenderRecord(runID: "new", name: "Login-iPhone 15", image: "Login-iPhone_15.png", device: "iPhone 15"), as: "Login-iPhone_15")
        try write(RenderRecord(runID: "new", name: "Button-2-secondary", image: "Button-2-secondary.png"), as: "Button-2-secondary")
        try write(RenderRecord(runID: "new", name: "Unknown", error: "Timed out"), as: "Unknown")
        try write(RenderRecord(runID: "old", name: "Gone", image: "Gone.png"), as: "Gone")
        try Data("not a record".utf8).write(to: directory.appendingPathComponent("notes.json"))

        let manifest = try RenderService.collect(in: directory, runID: "new", catalog: catalog, destination: "dest")

        XCTAssertEqual(manifest.runID, "new")
        XCTAssertEqual(manifest.destination, "dest")
        XCTAssertEqual(manifest.previews.map(\.record.name), ["Button-2-secondary", "Login-iPhone 15", "Unknown"])
        XCTAssertEqual(manifest.previews.map(\.source?.name), ["Button", "Login", nil])

        let files = try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted()
        XCTAssertEqual(files, [
            "Button-2-secondary.json", "Button-2-secondary.png", "Login-iPhone_15.json", "Login-iPhone_15.png", "Unknown.json", "notes.json",
        ])
    }

    func test_render_runsXcodebuildAndWritesTheManifest() throws {
        let runner = FakeRunner { arguments, environment in
            let options = try JSONDecoder().decode(RenderOptions.self, from: Data(environment["TEST_RUNNER_PREFIRE_RENDER"]!.utf8))
            XCTAssertEqual(options.runID, "run-1")
            XCTAssertEqual(options.devices, ["iPad"])
            XCTAssertTrue(arguments.contains("-only-testing:AppTests"))
            try self.write(RenderRecord(runID: options.runID, name: "Button", image: "Button.png", userStory: "Checkout"), as: "Button", in: URL(fileURLWithPath: options.directory))
            return 0
        }
        let service = RenderService(
            configuration: RenderConfiguration(scheme: "App", testTarget: "AppTests", outputDirectory: directory),
            runner: runner,
            makeRunID: { "run-1" }
        )

        let result = try service.render(RenderRequest(devices: ["iPad"]))

        XCTAssertEqual(result.status, 0)
        XCTAssertEqual(result.manifest.previews.map(\.record.userStory), ["Checkout"])
        XCTAssertEqual(try RenderManifest.read(from: directory).previews, result.manifest.previews)
        XCTAssertEqual(result.imageURL(of: result.manifest.previews[0])?.lastPathComponent, "Button.png")
    }

    func test_render_throws_whenXcodebuildFailsWithoutRendering() {
        let service = RenderService(
            configuration: RenderConfiguration(scheme: "App", outputDirectory: directory),
            runner: FakeRunner { _, _ in 65 }
        )

        XCTAssertThrowsError(try service.render(RenderRequest())) { error in
            guard case RenderError.nothingRendered(65, _) = error else {
                return XCTFail("Unexpected error \(error)")
            }
        }
    }

    func test_render_throws_whenTheTestsDoNotRunInRenderMode() {
        let service = RenderService(
            configuration: RenderConfiguration(scheme: "App", outputDirectory: directory),
            runner: FakeRunner { _, _ in 0 }
        )

        XCTAssertThrowsError(try service.render(RenderRequest(previews: ["Button"]))) { error in
            guard case RenderError.notInRenderMode = error else {
                return XCTFail("Unexpected error \(error)")
            }
        }
    }

    func test_render_returnsNoPreviews_whenTheTestsRanButNoneMatched() throws {
        let runner = FakeRunner { _, environment in
            let options = try JSONDecoder().decode(RenderOptions.self, from: Data(environment["TEST_RUNNER_PREFIRE_RENDER"]!.utf8))
            try Data(options.runID.utf8).write(to: URL(fileURLWithPath: options.directory).appendingPathComponent(RenderOptions.runMarkerFileName))
            return 0
        }
        let service = RenderService(configuration: RenderConfiguration(scheme: "App", outputDirectory: directory), runner: runner)

        let result = try service.render(RenderRequest(previews: ["Unknown"]))

        XCTAssertEqual(result.status, 0)
        XCTAssertEqual(result.manifest.previews, [])
    }

    func test_render_ignoresTheMarkerOfAnEarlierRun() throws {
        try Data("earlier".utf8).write(to: directory.appendingPathComponent(RenderOptions.runMarkerFileName))
        let service = RenderService(
            configuration: RenderConfiguration(scheme: "App", outputDirectory: directory),
            runner: FakeRunner { _, _ in 0 },
            makeRunID: { "now" }
        )

        XCTAssertThrowsError(try service.render(RenderRequest()))
    }

    func test_render_rejectsUnknownAppearance() {
        let service = RenderService(configuration: RenderConfiguration(scheme: "App", outputDirectory: directory), runner: FakeRunner { _, _ in 0 })

        XCTAssertThrowsError(try service.render(RenderRequest(colorScheme: "sepia")))
        XCTAssertThrowsError(try service.render(RenderRequest(dynamicType: "huge")))
    }

    private func write(_ record: RenderRecord, as baseName: String, in directory: URL? = nil) throws {
        let directory = directory ?? self.directory!
        try JSONEncoder().encode(record).write(to: directory.appendingPathComponent(baseName + ".json"))
        if let image = record.image {
            try Data([0x89]).write(to: directory.appendingPathComponent(image))
        }
    }
}

private struct FakeRunner: ProcessRunning, @unchecked Sendable {
    let body: ([String], [String: String]) throws -> Int32

    init(_ body: @escaping ([String], [String: String]) throws -> Int32) {
        self.body = body
    }

    func run(executable: String, arguments: [String], environment: [String: String], logFile: URL) throws -> Int32 {
        try body(arguments, environment)
    }
}
