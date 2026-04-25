import SwiftUI
import AppKit

struct MenuBarLabel: View {
    @ObservedObject var viewModel: UsageViewModel

    var body: some View {
        HStack(spacing: 3) {
            Image(nsImage: Self.appIcon)
                .frame(width: 16, height: 16)

            Text("\(Int(viewModel.menuBarPercentage))%")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .monospacedDigit()
        }
    }

    private static let appIcon: NSImage = {
        let pointSize = NSSize(width: 16, height: 16)
        let resourceNames = ["menubar-icon-16", "menubar-icon-32"]
        let image = NSImage(size: pointSize)
        var didAddRep = false

        for path in resolveCandidatePaths(for: resourceNames) {
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                  let rep = NSBitmapImageRep(data: data) else { continue }
            rep.size = pointSize
            image.addRepresentation(rep)
            didAddRep = true
        }

        if didAddRep {
            image.size = pointSize
            image.isTemplate = true
            return image
        }

        let fallback = NSImage(systemSymbolName: "sparkle", accessibilityDescription: "Token Meter")!
        fallback.isTemplate = true
        return fallback
    }()

    private static func resolveCandidatePaths(for names: [String]) -> [String] {
        let bundle = Bundle.main
        var paths: [String] = []

        for name in names {
            if let path = bundle.path(forResource: name, ofType: "png") {
                paths.append(path)
                continue
            }
            if let resourcePath = bundle.resourcePath {
                paths.append("\(resourcePath)/\(name).png")
            }
        }

        let execURL = URL(fileURLWithPath: ProcessInfo.processInfo.arguments[0])
        let resourcesDir = execURL
            .deletingLastPathComponent()  // MacOS/
            .deletingLastPathComponent()  // Contents/
            .appendingPathComponent("Contents/Resources")

        for name in names {
            paths.append(resourcesDir.appendingPathComponent("\(name).png").path)
        }

        return paths
    }
}
