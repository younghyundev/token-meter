import SwiftUI

/// Removes default content margins that macOS 15+ applies to MenuBarExtra popovers.
private struct MenuBarContentMarginsFix: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 15.0, *) {
            content.contentMargins(0)
        } else {
            content
        }
    }
}

@main
struct TokenMeterApp: App {
    @StateObject private var viewModel = UsageViewModel()

    var body: some Scene {
        MenuBarExtra {
            PopoverContentView(viewModel: viewModel)
                .ignoresSafeArea()
                .modifier(MenuBarContentMarginsFix())
                .task {
                    viewModel.start()
                }
        } label: {
            MenuBarLabel(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)
    }
}
