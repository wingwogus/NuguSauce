import Foundation

@MainActor
final class FavoritesViewModel: ObservableObject {
    @Published private(set) var recipes: [RecipeSummaryDTO] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let apiClient: APIClientProtocol
    private let authStore: AuthSessionStoreProtocol

    init(apiClient: APIClientProtocol, authStore: AuthSessionStoreProtocol) {
        self.apiClient = apiClient
        self.authStore = authStore
    }

    func load() async {
        guard authStore.isAuthenticated else {
            clearData()
            return
        }

        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
        }

        do {
            recipes = try await apiClient.fetchFavoriteRecipes()
        } catch {
            errorMessage = "찜한 레시피를 불러오지 못했어요."
        }
    }

    func clearData() {
        recipes = []
        isLoading = false
        errorMessage = nil
    }
}
