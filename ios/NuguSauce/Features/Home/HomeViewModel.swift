import Foundation

enum HomeBanner: String, CaseIterable, Identifiable {
    case openFeedback
    case createRecipe
    case searchRecipe

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .openFeedback:
            return "누구소스 오픈"
        case .createRecipe:
            return "나만의 소스 조합"
        case .searchRecipe:
            return "재료로 찾는 소스"
        }
    }

    var message: String {
        switch self {
        case .openFeedback:
            return "써보면서 불편한 점이나 원하는 기능을 남겨주세요."
        case .createRecipe:
            return "비율과 팁까지 남겨두고 다음에도 똑같이 만들어보세요."
        case .searchRecipe:
            return "가지고 있는 재료에 맞는 조합을 찾아보세요."
        }
    }

    var imageName: String {
        switch self {
        case .openFeedback:
            return "HomeBannerFeedback"
        case .createRecipe:
            return "HomeBannerCreate"
        case .searchRecipe:
            return "HomeBannerSearch"
        }
    }
}

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var recipes: [RecipeSummaryDTO] = []
    @Published private(set) var recentRecipes: [RecipeSummaryDTO] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    var popularRankingRecipes: [RecipeSummaryDTO] {
        Array(recipes.prefix(5))
    }

    var latestSourceRecipes: [RecipeSummaryDTO] {
        recentRecipes
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let home = try await apiClient.fetchHome()
            recipes = home.popularTop
            recentRecipes = home.recentTop
        } catch {
            errorMessage = "소스를 불러오지 못했어요."
        }
        isLoading = false
    }
}
