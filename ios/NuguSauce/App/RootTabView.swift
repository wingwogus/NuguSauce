import SwiftUI

enum RootTab: Hashable {
    case home
    case search
    case favorites
    case create
    case profile
}

@MainActor
final class RootTabSelection: ObservableObject {
    @Published var selectedTab: RootTab
    private var hasPresentedProfileSetup = false

    init(selectedTab: RootTab = .home) {
        self.selectedTab = selectedTab
    }

    func select(_ tab: RootTab) {
        selectedTab = tab
    }

    func profileSetupRequirementDidChange(isRequired: Bool) {
        if isRequired {
            hasPresentedProfileSetup = true
            return
        }

        if hasPresentedProfileSetup {
            selectedTab = .home
            hasPresentedProfileSetup = false
        }
    }
}

struct RootTabView: View {
    let apiClient: APIClientProtocol
    @ObservedObject var authStore: AuthSessionStore
    @StateObject private var tabSelection = RootTabSelection()
    @State private var createNavigationPath: [AppRoute] = []

    var body: some View {
        TabView(selection: $tabSelection.selectedTab) {
            NavigationStack {
                HomeView(
                    apiClient: apiClient,
                    authStore: authStore,
                    openSearch: { tabSelection.select(.search) }
                )
            }
            .tabItem {
                Label("홈", systemImage: "house.fill")
            }
            .tag(RootTab.home)

            NavigationStack {
                SearchView(apiClient: apiClient, authStore: authStore)
            }
            .tabItem {
                Label("검색", systemImage: "magnifyingglass")
            }
            .tag(RootTab.search)

            NavigationStack {
                FavoritesView(apiClient: apiClient, authStore: authStore)
            }
            .tabItem {
                Label("찜", systemImage: "bookmark.fill")
            }
            .tag(RootTab.favorites)

            NavigationStack(path: $createNavigationPath) {
                CreateRecipeView(
                    apiClient: apiClient,
                    authStore: authStore,
                    onCreatedRecipe: { recipeID in
                        createNavigationPath.append(.recipeDetail(recipeID))
                    }
                )
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .recipeDetail(let id):
                        RecipeDetailView(recipeID: id, apiClient: apiClient, authStore: authStore)
                    case .publicProfile:
                        PublicProfilePlaceholderView()
                    case .loginRequired:
                        LoginRequiredView(apiClient: apiClient, authStore: authStore)
                    }
                }
            }
            .tabItem {
                Label("등록", systemImage: "plus.circle.fill")
            }
            .tag(RootTab.create)

            NavigationStack {
                ProfileView(apiClient: apiClient, authStore: authStore)
            }
            .tabItem {
                Label("프로필", systemImage: "person.fill")
            }
            .tag(RootTab.profile)
        }
        .fullScreenCover(isPresented: profileSetupGateBinding) {
            ProfileSetupGateView(apiClient: apiClient, authStore: authStore)
                .interactiveDismissDisabled(true)
        }
        .onAppear {
            tabSelection.profileSetupRequirementDidChange(isRequired: authStore.requiresProfileSetup)
        }
        .onChange(of: authStore.requiresProfileSetup) { _, requiresProfileSetup in
            tabSelection.profileSetupRequirementDidChange(isRequired: requiresProfileSetup)
        }
    }

    private var profileSetupGateBinding: Binding<Bool> {
        Binding(
            get: {
                authStore.requiresProfileSetup
            },
            set: { _ in }
        )
    }
}
