import SwiftUI
import AppKit

struct MenuBarLabel: View {
    @ObservedObject var viewModel: UsageViewModel

    var body: some View {
        HStack(spacing: 3) {
            Image(nsImage: Self.claudeIcon)
                .frame(width: 16, height: 16)

            Text("\(Int(viewModel.sessionPercentage))%")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .monospacedDigit()
        }
    }

    private static let claudeIcon: NSImage = {
        let bundle = Bundle.main

        // Try loading the pixel art mascot icon
        let mascotCandidates = [
            bundle.path(forResource: "menubar-icon-16", ofType: "png"),
            bundle.resourcePath.map { "\($0)/menubar-icon-16.png" },
        ]

        for candidate in mascotCandidates {
            guard let path = candidate,
                  let image = NSImage(contentsOfFile: path) else { continue }
            image.isTemplate = true
            image.size = NSSize(width: 16, height: 16)
            return image
        }

        // Fallback: load from known path relative to executable
        let execURL = URL(fileURLWithPath: ProcessInfo.processInfo.arguments[0])
        let resourcesDir = execURL
            .deletingLastPathComponent()  // MacOS/
            .deletingLastPathComponent()  // Contents/
            .appendingPathComponent("Contents/Resources")

        let fallbackPath = resourcesDir.appendingPathComponent("menubar-icon-16.png").path
        if let image = NSImage(contentsOfFile: fallbackPath) {
            image.isTemplate = true
            image.size = NSSize(width: 16, height: 16)
            return image
        }

        // Last resort: SF Symbol
        let fallback = NSImage(systemSymbolName: "sparkle", accessibilityDescription: "Token Meter")!
        fallback.isTemplate = true
        return fallback
    }()
}
