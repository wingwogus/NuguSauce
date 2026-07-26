import SwiftUI
import KakaoSDKAuth
import KakaoSDKCommon

@main
struct NuguSauceApp: App {
    private let apiClient: APIClientProtocol
    @StateObject private var authStore: AuthSessionStore
    @StateObject private var adConsentManager = AdConsentManager()
    @AppStorage(SauceThemePreference.storageKey) private var themePreferenceRawValue = SauceThemePreference.system.rawValue

    init() {
        let authStore = AuthSessionStore()
        if ProcessInfo.processInfo.environment["NUGUSAUCE_RESET_AUTH_ON_LAUNCH"] == "1" {
            authStore.clear()
        }
        _authStore = StateObject(wrappedValue: authStore)
        let backendAPIClient = BackendAPIClient(authStore: authStore)
        apiClient = CachingAPIClient(upstream: backendAPIClient, authStore: authStore)
        if let nativeAppKey = KakaoSDKConfiguration.nativeAppKey {
            KakaoSDK.initSDK(appKey: nativeAppKey)
        }
    }

    var body: some Scene {
        WindowGroup {
            StartupSplashContainer {
                RootTabView(apiClient: apiClient, authStore: authStore)
            }
            .environmentObject(adConsentManager)
            .tint(SauceColor.primaryContainer)
            .preferredColorScheme(themePreference.colorScheme)
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnOutsideTap()
            .onOpenURL { url in
                if AuthApi.isKakaoTalkLoginUrl(url) {
                    _ = AuthController.handleOpenUrl(url: url)
                }
            }
            .task {
                await adConsentManager.requestConsentAndStartAds()
            }
        }
    }

    private var themePreference: SauceThemePreference {
        SauceThemePreference(rawValue: themePreferenceRawValue) ?? .system
    }
}
