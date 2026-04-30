import SwiftUI

enum RootTab: Hashable {
    case home
    case search
    case favorites
    case create
    case profile

    var requiresAuthentication: Bool {
        switch self {
        case .favorites, .create, .profile:
            return true
        case .home, .search:
            return false
        }
    }
}

@MainActor
final class RootTabSelection: ObservableObject {
    @Published private(set) var selectedTab: RootTab
    @Published private(set) var loginRequiredTab: RootTab?
    private var hasPresentedProfileSetup = false

    init(selectedTab: RootTab = .home) {
        self.selectedTab = selectedTab
    }

    func select(_ tab: RootTab, isAuthenticated: Bool = true) {
        selectedTab = tab
        if tab.requiresAuthentication && !isAuthenticated {
            loginRequiredTab = tab
        } else if loginRequiredTab == tab {
            loginRequiredTab = nil
        }
    }

    func authenticationDidChange(isAuthenticated: Bool) {
        if isAuthenticated {
            loginRequiredTab = nil
        } else if selectedTab.requiresAuthentication {
            loginRequiredTab = selectedTab
        } else {
            loginRequiredTab = nil
        }
    }

    func loginRouteDidOpen(for tab: RootTab) {
        if loginRequiredTab == tab {
            loginRequiredTab = nil
        }
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
    @State private var favoritesNavigationPath: [AppRoute] = []
    @State private var createNavigationPath: [AppRoute] = []
    @State private var profileNavigationPath: [AppRoute] = []

    var body: some View {
        TabView(selection: selectedTabBinding) {
            NavigationStack {
                HomeView(
                    apiClient: apiClient,
                    authStore: authStore,
                    openProfile: { tabSelection.select(.profile, isAuthenticated: authStore.isAuthenticated) }
                )
                .navigationDestination(for: AppRoute.self) { route in
                    destination(for: route)
                }
            }
            .tabItem {
                Label("홈", systemImage: "house.fill")
            }
            .tag(RootTab.home)

            NavigationStack {
                SearchView(apiClient: apiClient, authStore: authStore)
                    .navigationDestination(for: AppRoute.self) { route in
                        destination(for: route)
                    }
            }
            .tabItem {
                Label("검색", systemImage: "magnifyingglass")
            }
            .tag(RootTab.search)

            NavigationStack(path: $favoritesNavigationPath) {
                FavoritesView(apiClient: apiClient, authStore: authStore)
                    .navigationDestination(for: AppRoute.self) { route in
                        destination(for: route)
                    }
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
                    destination(for: route)
                }
            }
            .tabItem {
                Label("등록", systemImage: "plus.circle.fill")
            }
            .tag(RootTab.create)

            NavigationStack(path: $profileNavigationPath) {
                ProfileView(apiClient: apiClient, authStore: authStore)
                    .navigationDestination(for: AppRoute.self) { route in
                        destination(for: route)
                    }
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
            tabSelection.authenticationDidChange(isAuthenticated: authStore.isAuthenticated)
            if let loginRequiredTab = tabSelection.loginRequiredTab {
                routeToLogin(for: loginRequiredTab)
            }
            tabSelection.profileSetupRequirementDidChange(isRequired: authStore.requiresProfileSetup)
        }
        .onChange(of: tabSelection.loginRequiredTab) { _, loginRequiredTab in
            if let loginRequiredTab {
                routeToLogin(for: loginRequiredTab)
            }
        }
        .onChange(of: authStore.isAuthenticated) { _, isAuthenticated in
            tabSelection.authenticationDidChange(isAuthenticated: isAuthenticated)
            if isAuthenticated {
                removeLoginRoutes()
            } else if let loginRequiredTab = tabSelection.loginRequiredTab {
                routeToLogin(for: loginRequiredTab)
            }
        }
        .onChange(of: authStore.requiresProfileSetup) { _, requiresProfileSetup in
            tabSelection.profileSetupRequirementDidChange(isRequired: requiresProfileSetup)
        }
    }

    private var selectedTabBinding: Binding<RootTab> {
        Binding(
            get: {
                tabSelection.selectedTab
            },
            set: { tab in
                tabSelection.select(tab, isAuthenticated: authStore.isAuthenticated)
            }
        )
    }

    private var profileSetupGateBinding: Binding<Bool> {
        Binding(
            get: {
                authStore.requiresProfileSetup
            },
            set: { _ in }
        )
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .recipeDetail(let id):
            RecipeDetailView(recipeID: id, apiClient: apiClient, authStore: authStore)
        case .publicProfile(let id):
            PublicProfileView(memberID: id, apiClient: apiClient)
        case .login:
            LoginView(apiClient: apiClient, authStore: authStore)
        }
    }

    private func routeToLogin(for tab: RootTab) {
        switch tab {
        case .favorites:
            if !favoritesNavigationPath.contains(.login) {
                favoritesNavigationPath.append(.login)
            }
        case .create:
            if !createNavigationPath.contains(.login) {
                createNavigationPath.append(.login)
            }
        case .profile:
            if !profileNavigationPath.contains(.login) {
                profileNavigationPath.append(.login)
            }
        case .home, .search:
            break
        }
        tabSelection.loginRouteDidOpen(for: tab)
    }

    private func removeLoginRoutes() {
        favoritesNavigationPath.removeAll { $0 == .login }
        createNavigationPath.removeAll { $0 == .login }
        profileNavigationPath.removeAll { $0 == .login }
    }
}
