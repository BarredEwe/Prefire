## 📸 Snapshot timing and precision

By default Prefire captures a preview right after its first render. The `.snapshot(...)` modifiers
change when the snapshot is taken and how strictly it is compared.

| Need | Modifier |
|------|----------|
| Fixed pause, comparison tolerance | `.snapshot(delay: 0.3, precision: 0.95, perceptualPrecision: 0.98)` |
| Wait until the preview stops changing | `.snapshot(waitForIdle: true)` |
| Wait for a condition | `.snapshot(waitUntil: { viewModel.isLoaded })` |

---

### Delay and precision

Set the delay, precision and perceptualPrecision parameters for the snapshot:

```swift
static var previews: some View {
    TestView()
        .snapshot(delay: 0.3, precision: 0.95, perceptualPrecision: 0.98)
}
```

---

### Wait for idle

Instead of guessing a delay, you can wait until the preview stops changing:

```swift
.snapshot(waitForIdle: true)
.snapshot(waitForIdle: true, timeout: 2.0)
```

Prefire renders the preview, compares the frames it would capture every 50 ms, and takes the
snapshot once nothing changed for 300 ms. A preview that never settles fails with a message
instead of hanging, after `timeout` (5 seconds by default).

Put the modifier on content that is there from the first render: one inside content that only
shows up later, such as an `if isLoaded` branch or a `List` row, is not seen.

Waiting for idle only sees what is drawn: a preview that shows the same frame for longer while
it loads, or runs a Core Animation animation such as a `ProgressView` spinner, looks idle. Use
`.snapshot(waitUntil:)` for those, or a `delay` as a floor: Prefire spends it before it starts
comparing frames, and does not wait it out a second time when capturing. Both modifiers can be
combined, since they configure different things:

```swift
static var previews: some View {
    TestView()
        .snapshot(delay: 0.1, precision: 0.95)
        .snapshot(waitForIdle: true)
}
```

Set `snapshot_wait_for_idle: true` in [`.prefire.yml`](Configuration.md) to make it the default
for every preview, and opt single previews out with `.snapshot(waitForIdle: false)`.

---

### Wait for a condition

When the preview itself knows when it is ready, wait for a condition:

```swift
.snapshot(waitUntil: { viewModel.isLoaded })
.snapshot(waitUntil: { viewModel.isLoaded }, timeout: 2.0)
```

The condition is checked on the main thread while the preview keeps rendering, and the test
fails with the call site of the modifier when it is still `false` after `timeout`.

A helper wrapping the modifier can pass its own call site on, so a timeout names the preview
that uses it:

```swift
extension View {
    func waitingUntilLoaded(_ viewModel: ViewModel, fileID: String = #fileID, line: UInt = #line) -> some View {
        snapshot(waitUntil: { viewModel.isLoaded }, fileID: fileID, line: line)
    }
}
```

---

### How waits combine

When several views of a preview wait, a condition is waited for over idle, every condition has
to be met, `.snapshot(waitForIdle: false)` of one view does not cancel the wait of another, and
the longest timeout applies.

The preview is hosted once, waited on and captured in the same window, so state it reached in
`.onAppear` or `.task` is kept. Accessibility snapshots are the exception: they render the
preview anew and only honor `delay`. With both VoiceOver strategies enabled, text and the
accessibility image share one host and spend `delay` once, separate from the regular image.
Text is read before image overlays are added and waits for two matching reads, about 50 ms apart
following the initial layout pass. See [VoiceOver snapshots](Configuration.md#voiceover-snapshots).

Waiting runs the main run loop in place, so snapshots that wait have to be taken from a
synchronous test method, as the generated tests do. From `async` code `.task` never runs, and
the timeout message says so.
