import SwiftUI
import KakaoSDKAuth
import KakaoSDKCommon

@main
struct NuguSauceApp: App {
    private let apiClient: BackendAPIClient
    @StateObject private var authStore: AuthSessionStore
    @AppStorage(SauceThemePreference.storageKey) private var themePreferenceRawValue = SauceThemePreference.system.rawValue

    init() {
        let authStore = AuthSessionStore()
        _authStore = StateObject(wrappedValue: authStore)
        apiClient = BackendAPIClient(authStore: authStore)
        if let nativeAppKey = KakaoSDKConfiguration.nativeAppKey {
            KakaoSDK.initSDK(appKey: nativeAppKey)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView(apiClient: apiClient, authStore: authStore)
                .tint(SauceColor.primaryContainer)
                .preferredColorScheme(themePreference.colorScheme)
                .onOpenURL { url in
                    if AuthApi.isKakaoTalkLoginUrl(url) {
                        _ = AuthController.handleOpenUrl(url: url)
                    }
                }
        }
    }

    private var themePreference: SauceThemePreference {
        SauceThemePreference(rawValue: themePreferenceRawValue) ?? .system
    }
}
