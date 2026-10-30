import Foundation

let fixtureVoiceOverConsumerSource = #filePath

#if os(iOS)
import SwiftUI

// Solid pixels keep the generated end-to-end reference independent of OS font rendering.
#Preview("VoiceOver CI", traits: .fixedLayout(width: 8, height: 8)) {
    Color.white
        .frame(width: 8, height: 8)
        .accessibilityElement()
        .accessibilityLabel("Generated VoiceOver")
        .accessibilityIdentifier("voiceover-ci")
}
#endif
