import SwiftUI

struct RootTabView: View {
    let apiClient: APIClientProtocol
    @ObservedObject var authStore: MockAuthSessionStore

    var body: some View {
        TabView {
            NavigationStack {
                HomeView(apiClient: apiClient, authStore: authStore)
            }
            .tabItem {
                Label("홈", systemImage: "house.fill")
            }

            NavigationStack {
                SearchView(apiClient: apiClient, authStore: authStore)
            }
            .tabItem {
                Label("검색", systemImage: "magnifyingglass")
            }

            NavigationStack {
                CreateRecipeView(apiClient: apiClient, authStore: authStore)
            }
            .tabItem {
                Label("등록", systemImage: "plus.circle.fill")
            }

            NavigationStack {
                ProfileView(apiClient: apiClient, authStore: authStore)
            }
            .tabItem {
                Label("프로필", systemImage: "person.fill")
            }
        }
    }
}
