import SwiftUI

private enum RootTab: Hashable {
    case home
    case search
    case favorites
    case create
    case profile
}

struct RootTabView: View {
    let apiClient: APIClientProtocol
    @ObservedObject var authStore: AuthSessionStore
    @State private var selectedTab: RootTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView(
                    apiClient: apiClient,
                    authStore: authStore,
                    openSearch: { selectedTab = .search }
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

            NavigationStack {
                CreateRecipeView(apiClient: apiClient, authStore: authStore)
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
    }
}
