## 🤖 Letting AI agents see SwiftUI

An agent that changes a SwiftUI view can't see the result. Xcode Previews can render it, but
through Xcode only, on whatever device the canvas has, and a canvas that is stale or crashed shows
the old code. Prefire already renders every preview in its snapshot tests, built anew and on the
devices you name, so it can show them to an agent, or to you, as plain PNG files:

- `prefire render` builds the app and writes previews as images, with a JSON record of each one.
- `prefire mcp` serves the same as an [MCP](https://modelcontextprotocol.io) server, so an agent
  renders previews and gets the images back in the conversation.
- `prefire board` lays the last render out as an HTML flow board, grouped by `previewUserStory`.

Rendering runs the generated snapshot tests (`prefire tests`) in render mode: instead of comparing
each preview with its reference image, the tests write it into a directory. Reference images are
neither compared nor changed.

### Setup

Generate the snapshot tests as usual, then tell Prefire how to run them in `.prefire.yml`:

```yaml
test_configuration:
  target: MyApp
  sources:
    - ${PROJECT_DIR}/Sources/

render_configuration:
  scheme: MyApp                    # scheme that runs the snapshot tests (required)
  workspace: MyApp.xcworkspace     # or `project: MyApp.xcodeproj`
  destination: platform=iOS Simulator,name=iPhone 16
  test_target: MyAppSnapshotTests  # lets only the tests of the previews asked for run
  output_dir: .prefire/render
```

| Key           | Description                                                                                                                                                         |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `scheme`      | Scheme whose test action includes the generated snapshot tests. Required.                                                                                           |
| `workspace`   | `.xcworkspace` to build. Optional.                                                                                                                                  |
| `project`     | `.xcodeproj` to build, when there is no workspace. Optional.                                                                                                        |
| `destination` | `-destination` of `xcodebuild`. Default: `platform=iOS Simulator,name=iPhone 16`                                                                                    |
| `test_target` | Target of the generated tests. With it, `xcodebuild` runs only the tests of the previews asked for, and never the other tests of the scheme. Recommended. With a `template_file_path` of your own, the whole target runs and the tests pick the previews. |
| `output_dir`  | Directory of the images, their records, `manifest.json` and `board.html`. Default: `.prefire/render`. Add it to `.gitignore`.                                       |
| `sources`     | Files or folders the previews are looked for in. Default: `sources` of `test_configuration`, or the current directory.                                             |
| `xcodebuild_args` | Arguments passed on to `xcodebuild` after Prefire's own, like `-derivedDataPath` and its value, or `-skipPackagePluginValidation`. Optional.                   |

Outside of Xcode `${PROJECT_DIR}` is the folder of the config given with `--config`, or the current
directory, so `sources` written for `prefire tests` work as they are.

Every key can be given on the command line too (`--scheme`, `--workspace`, `--project`,
`--destination`, `--test-target`, `--output`, `--source`, `--xcodebuild-arg`), which wins over the
file. `--xcodebuild-arg` values add to `xcodebuild_args`.

### `prefire render`

```bash
# All previews
prefire render

# Some previews, on two devices, dark, with large text
prefire render "Sign in" "Cart" --device "iPhone 16 Pro" --device iPad --color-scheme dark --dynamic-type accessibility2

# The previews Prefire knows, with their source location
prefire render --list
```

- Previews are named as their snapshots are: the name of the `#Preview`, or `<File>_<index>` for an
  unnamed one. A name also selects the snapshots that add a suffix to it, like those of
  `#Preview(..., arguments:)` or of each of `snapshot_devices`.
- `--device` renders screen previews (components keep their canvas) on the devices named, with their real safe area and scale,
  instead of `snapshot_devices`. The names are those of `snapshot_devices`; an unknown one gets a
  record with the error and the names Prefire knows. Devices are ignored on macOS.
- A `PreviewProvider` marked `PrefireProvider` is asked for by its type name, like `Card_Previews`,
  and renders all its previews.
- `--color-scheme`: `light` or `dark`. `--dynamic-type`: `xSmall` … `xxxLarge`, `accessibility1` …
  `accessibility5`.
- Each preview is written as `<name>.png` next to `<name>.json` (name, device, size, scale,
  user story, state, and an error when it could not be rendered). `manifest.json` lists the
  previews of the last run in source order, with the file and line each is declared on. Files of
  earlier runs are removed once a run renders, so a build that fails keeps the last render.
- Names that match no preview, and devices asked for on macOS, are reported as warnings.
- One render at a time writes to an output directory: another, like one of `prefire mcp`, waits.
- The output of `xcodebuild` goes to `xcodebuild.log` in the output directory. `--json` prints the
  manifest; otherwise a line per preview is printed.
- The command exits with the status of `xcodebuild`, which is not 0 when a preview failed to render.
- When `xcodebuild` succeeds but no snapshot test ran in render mode, the command fails and says so.
  It happens when the scheme or `test_target` don't run the generated tests, or when they were
  generated by a Prefire without render mode: update the Prefire package and its plugin.

### `prefire mcp`

Runs an MCP server over standard input and output. Add it to your agent from the folder with
`.prefire.yml`:

| Agent       | Install |
| ----------- | ------- |
| Claude Code | `claude mcp add prefire -- prefire mcp` |
| Claude Code, with a skill that tells Claude when and how to render | `/plugin marketplace add BarredEwe/Prefire`, then `/plugin install prefire@prefire` |
| Cursor      | [Add to Cursor](https://cursor.com/en/install-mcp?name=prefire&config=eyJjb21tYW5kIjoicHJlZmlyZSIsImFyZ3MiOlsibWNwIl19) |
| Codex       | `codex mcp add prefire -- prefire mcp` |
| VS Code     | `code --add-mcp '{"name":"prefire","command":"prefire","args":["mcp"]}'` |

A client that does not start servers in the project folder needs `--config` with the path of
`.prefire.yml`, or any other MCP client:

```json
{
  "mcpServers": {
    "prefire": { "command": "prefire", "args": ["mcp", "--config", "/path/to/.prefire.yml"] }
  }
}
```

Each release also attaches `prefire-mcp-<version>.mcpb`, an [MCP Bundle](https://github.com/modelcontextprotocol/mcpb)
with the macOS `prefire` binary, and lists the server in the
[MCP Registry](https://registry.modelcontextprotocol.io) as `io.github.BarredEwe/prefire`. Clients
that install bundles, like Claude Desktop, open the file and ask for the `.prefire.yml` of the
project. `make mcpb` packs one from the bundled binary (it needs Node) and writes its address and
SHA-256 into `server.json`, which the release workflow publishes.

| Tool              | Arguments                                                                                         | Returns                                                                                  |
| ----------------- | ------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| `list_previews`   | —                                                                                                 | The previews: name, kind, file, line, and whether it is a screen.                       |
| `render_previews` | `previews`, `devices`, `color_scheme`, `dynamic_type`, `max_images` (default 6)                  | A JSON summary with the path of every image, then up to `max_images` images.            |
| `build_board`     | `embed_images`                                                                                    | Path of the board of the last render.                                                    |

A render builds the project, so it takes as long as a test run. Raise the tool timeout of your
client if it gives up sooner (Claude Code: `MCP_TOOL_TIMEOUT`, in milliseconds). Ask for the
previews you need rather than all of them: with `test_target` set, only their tests run.

The Claude Code plugin adds the `swiftui-preview` skill: Claude lists the previews, renders the ones
it changed on a few devices and in dark mode, and reads the errors, before it calls a UI change done.

### `prefire board`

```bash
prefire render && prefire board
open .prefire/render/board.html
```

Writes `board.html` next to `manifest.json`: a row for each `previewUserStory`, its previews in the
order they are declared, each with its `previewState`, device and source location. Previews
without a user story come last. The page follows the light or dark appearance of the system.
`--embed-images` puts the images into the page, so it can be shared as one file.

```swift
#Preview("Sign in") {
    SignInView()
        .previewUserStory(.auth)
        .previewState(.empty)
}

#Preview("Sign in, error") {
    SignInView(error: .wrongPassword)
        .previewUserStory(.auth)
        .previewState(.error)
}
```

### Notes

- Render mode is turned on by the `PREFIRE_RENDER` environment variable (`TEST_RUNNER_PREFIRE_RENDER`
  for `xcodebuild`), which holds the options as JSON. The tests run as usual without it. With it
  they compare nothing and pass, and say so in their output: don't set it in a scheme.
- Images are rendered the way the snapshot tests render them. Previews that wait, with
  `.snapshot(delay:)`, `.snapshot(waitForIdle:)` or `.snapshot(waitUntil:)`, are rendered once they
  settled. `SKView`, `SCNView` and `WKWebView` are drawn as images, as SnapshotTesting
  draws them.
- Snapshots of a `PreviewProvider` marked `PrefireProvider` are named by its previews, and found by
  its type name or by those names.
- macOS previews are rendered too, with the color scheme and Dynamic Type asked for; `--device`
  applies to iOS and tvOS.
