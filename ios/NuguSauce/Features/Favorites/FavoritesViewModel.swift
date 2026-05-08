import Foundation

@MainActor
final class FavoritesViewModel: ObservableObject {
    @Published private(set) var recipes: [RecipeSummaryDTO] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let apiClient: APIClientProtocol
    private let authStore: AuthSessionStoreProtocol
    private var requestGeneration = 0

    init(apiClient: APIClientProtocol, authStore: AuthSessionStoreProtocol) {
        self.apiClient = apiClient
        self.authStore = authStore
    }

    func load() async {
        await loadFavorites(invalidateCache: false)
    }

    func refresh() async {
        await loadFavorites(invalidateCache: true)
    }

    func clearData() {
        requestGeneration += 1
        recipes = []
        isLoading = false
        errorMessage = nil
    }

    private func loadFavorites(invalidateCache: Bool) async {
        guard authStore.isAuthenticated else {
            clearData()
            return
        }

        requestGeneration += 1
        let currentGeneration = requestGeneration
        isLoading = true
        errorMessage = nil

        if invalidateCache, let cacheControl = apiClient as? CacheControllingAPIClient {
            await cacheControl.invalidate(scope: .favorites)
            guard isCurrentGeneration(currentGeneration), authStore.isAuthenticated else {
                return
            }
        }

        do {
            let loadedRecipes = try await apiClient.fetchFavoriteRecipes()
            guard isCurrentGeneration(currentGeneration), authStore.isAuthenticated else {
                return
            }
            recipes = loadedRecipes
        } catch {
            guard isCurrentGeneration(currentGeneration), authStore.isAuthenticated else {
                return
            }
            errorMessage = "찜한 소스를 불러오지 못했어요."
        }

        if isCurrentGeneration(currentGeneration) {
            isLoading = false
        }
    }

    private func isCurrentGeneration(_ generation: Int) -> Bool {
        generation == requestGeneration
    }
}
