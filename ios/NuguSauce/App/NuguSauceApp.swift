import SwiftUI

@main
struct NuguSauceApp: App {
    private let apiClient = MockAPIClient()
    @StateObject private var authStore = MockAuthSessionStore(isAuthenticated: true)

    var body: some Scene {
        WindowGroup {
            RootTabView(apiClient: apiClient, authStore: authStore)
                .tint(SauceColor.primaryContainer)
        }
    }
}
