import Foundation

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published private(set) var myRecipes: [RecipeSummaryDTO] = []
    @Published private(set) var favoriteRecipes: [RecipeSummaryDTO] = []
    @Published private(set) var errorMessage: String?

    private let apiClient: APIClientProtocol
    private let authStore: AuthSessionStoreProtocol

    init(apiClient: APIClientProtocol, authStore: AuthSessionStoreProtocol) {
        self.apiClient = apiClient
        self.authStore = authStore
    }

    var session: AuthSession? {
        authStore.currentSession
    }

    var isAuthenticated: Bool {
        authStore.isAuthenticated
    }

    func load() async {
        guard authStore.isAuthenticated else {
            clearData()
            return
        }
        do {
            async let myRecipes = apiClient.fetchMyRecipes()
            async let favoriteRecipes = apiClient.fetchFavoriteRecipes()
            self.myRecipes = try await myRecipes
            self.favoriteRecipes = try await favoriteRecipes
        } catch {
            errorMessage = "프로필 정보를 불러오지 못했어요."
        }
    }

    func clearData() {
        myRecipes = []
        favoriteRecipes = []
        errorMessage = nil
    }
}
