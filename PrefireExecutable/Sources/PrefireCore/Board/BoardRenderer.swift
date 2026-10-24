import Foundation

/// Renders a render manifest as a flow board: a self-contained HTML page with the previews of each
/// user story in a row, in the order they are declared.
public enum BoardRenderer {
    public static let fileName = "board.html"

    /// Previews of one user story.
    struct Story: Equatable {
        /// `previewUserStory` of the previews, or `nil` for those without one.
        var name: String?
        var previews: [RenderedPreview]
    }

    /// Writes the board of the manifest in `directory` next to it.
    ///
    /// - Parameter embedImages: Puts the images into the page, so it can be moved without them.
    /// - Returns: The written page.
    @discardableResult
    public static func write(directory: URL, embedImages: Bool) throws -> URL {
        let manifest = try RenderManifest.read(from: directory)
        let page = html(for: manifest) { image in
            guard embedImages else { return image }
            guard let data = try? Data(contentsOf: directory.appendingPathComponent(image)) else { return image }
            return "data:image/png;base64," + data.base64EncodedString()
        }
        let url = directory.appendingPathComponent(fileName)
        try Data(page.utf8).write(to: url, options: .atomic)
        return url
    }

    /// Stories of `previews` in the order they first appear, those without one last.
    static func stories(of previews: [RenderedPreview]) -> [Story] {
        var stories: [Story] = []
        for preview in previews {
            let name = preview.record.userStory.flatMap { $0.isEmpty ? nil : $0 }
            if let index = stories.firstIndex(where: { $0.name == name }) {
                stories[index].previews.append(preview)
            } else {
                stories.append(Story(name: name, previews: [preview]))
            }
        }
        return stories.filter { $0.name != nil } + stories.filter { $0.name == nil }
    }

    /// The page.
    ///
    /// - Parameter imageSource: `src` of an image, from its file name in the render directory.
    static func html(for manifest: RenderManifest, imageSource: (String) -> String = { $0 }) -> String {
        let stories = stories(of: manifest.previews)
        let date = ISO8601DateFormatter().string(from: manifest.createdAt)
        let subtitle = [
            "\(manifest.previews.count) preview\(manifest.previews.count == 1 ? "" : "s")",
            manifest.destination,
            date,
        ].compactMap { $0 }.map(escape).joined(separator: " · ")

        let body = stories.isEmpty
            ? #"<p class="empty">Nothing was rendered. Run <code>prefire render</code> first.</p>"#
            : stories.map { section(for: $0, imageSource: imageSource) }.joined(separator: "\n")

        return """
        <!doctype html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Prefire Board</title>
        <style>\(style)</style>
        </head>
        <body>
        <header>
        <h1>Prefire Board</h1>
        <p class="subtitle">\(subtitle)</p>
        </header>
        <main>
        \(body)
        </main>
        </body>
        </html>

        """
    }

    private static func section(for story: Story, imageSource: (String) -> String) -> String {
        let title = story.name.map(escape) ?? "Other previews"
        let cards = story.previews.map { card(for: $0, imageSource: imageSource) }
        let flow = cards.joined(separator: story.name == nil ? "\n" : "\n<div class=\"arrow\" aria-hidden=\"true\">→</div>\n")
        return """
        <section class="story">
        <h2>\(title) <span class="count">\(story.previews.count)</span></h2>
        <div class="flow">
        \(flow)
        </div>
        </section>
        """
    }

    private static func card(for preview: RenderedPreview, imageSource: (String) -> String) -> String {
        let record = preview.record
        var figure: String
        if let image = record.image {
            let size = record.width > 0 ? #" style="width: \#(Int(min(record.width, 320)))px""# : ""
            figure = #"<img src="\#(escape(imageSource(image)))" alt="\#(escape(record.name))" loading="lazy"\#(size)>"#
        } else {
            figure = #"<div class="missing">Not rendered</div>"#
        }
        if let error = record.error {
            figure += #"<p class="error">\#(escape(error))</p>"#
        }

        let tags = [record.device, record.colorScheme, record.dynamicType].compactMap { $0 }
            .map { #"<span class="tag">\#(escape($0))</span>"# }
            .joined()
        let state = record.state.map { #"<span class="state">\#(escape($0))</span>"# } ?? ""
        let source = preview.source.map { source in
            let file = URL(fileURLWithPath: source.file).lastPathComponent
            return #"<p class="source" title="\#(escape(source.file)):\#(source.line)">\#(escape(file)):\#(source.line)</p>"#
        } ?? ""

        return """
        <figure class="card">
        <div class="frame">\(figure)</div>
        <figcaption><p class="name">\(escape(record.name))</p>\(state)\(tags)\(source)</figcaption>
        </figure>
        """
    }

    /// `text` with the characters HTML gives a meaning to escaped.
    static func escape(_ text: String) -> String {
        var escaped = ""
        escaped.reserveCapacity(text.count)
        for character in text {
            switch character {
            case "&": escaped += "&amp;"
            case "<": escaped += "&lt;"
            case ">": escaped += "&gt;"
            case "\"": escaped += "&quot;"
            case "'": escaped += "&#39;"
            default: escaped.append(character)
            }
        }
        return escaped
    }

    private static let style = """
    :root {
      color-scheme: light dark;
      --background: #f5f5f7;
      --surface: #ffffff;
      --text: #1d1d1f;
      --secondary: #6e6e73;
      --border: #d2d2d7;
      --accent: #0071e3;
      --error: #d70015;
      --checker: #ececf0;
    }
    @media (prefers-color-scheme: dark) {
      :root {
        --background: #161617;
        --surface: #232325;
        --text: #f5f5f7;
        --secondary: #a1a1a6;
        --border: #3a3a3c;
        --accent: #2997ff;
        --error: #ff6961;
        --checker: #2c2c2e;
      }
    }
    * { box-sizing: border-box; }
    body { margin: 0; background: var(--background); color: var(--text); font: 14px/1.4 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }
    header { padding: 24px 16px 8px; }
    h1 { margin: 0; font-size: 24px; }
    .subtitle { margin: 4px 0 0; color: var(--secondary); }
    main { padding: 8px 16px 32px; }
    .story { margin-top: 24px; }
    h2 { margin: 0 0 12px; font-size: 17px; }
    .count { color: var(--secondary); font-weight: normal; }
    .flow { display: flex; gap: 12px; align-items: flex-start; overflow-x: auto; padding-bottom: 8px; }
    .arrow { align-self: center; color: var(--secondary); font-size: 20px; }
    .card { flex: none; margin: 0; max-width: 344px; background: var(--surface); border: 1px solid var(--border); border-radius: 12px; padding: 12px; }
    .frame { background: repeating-conic-gradient(var(--checker) 0% 25%, transparent 0% 50%) 50% / 16px 16px; border-radius: 6px; overflow: hidden; }
    .frame img { display: block; max-width: 100%; height: auto; }
    .missing { padding: 32px 16px; text-align: center; color: var(--secondary); }
    figcaption { margin-top: 8px; }
    .name { margin: 0 0 4px; font-weight: 600; word-break: break-word; }
    .state, .tag { display: inline-block; margin: 0 4px 4px 0; padding: 1px 8px; border-radius: 10px; font-size: 12px; }
    .state { background: var(--accent); color: #fff; }
    .tag { border: 1px solid var(--border); color: var(--secondary); }
    .source { margin: 4px 0 0; color: var(--secondary); font-size: 12px; }
    .error { margin: 8px; color: var(--error); white-space: pre-wrap; }
    .empty { color: var(--secondary); }
    """
}
