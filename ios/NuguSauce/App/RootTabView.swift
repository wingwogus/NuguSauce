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
        if tab.requiresAuthentication && !isAuthenticated {
            loginRequiredTab = tab
            return
        }

        selectedTab = tab
        if loginRequiredTab == tab {
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

private struct RootLoginPresentation: Identifiable {
    let requestedTab: RootTab

    var id: RootTab {
        requestedTab
    }
}

struct RootTabView: View {
    let apiClient: APIClientProtocol
    @ObservedObject var authStore: AuthSessionStore
    @StateObject private var tabSelection = RootTabSelection()
    @State private var favoritesNavigationPath: [AppRoute] = []
    @State private var createNavigationPath: [AppRoute] = []
    @State private var profileNavigationPath: [AppRoute] = []
    @State private var rootLoginPresentation: RootLoginPresentation?

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

            NavigationStack(path: $favoritesNavigationPath) {
                FavoritesView(apiClient: apiClient, authStore: authStore)
                    .navigationDestination(for: AppRoute.self) { route in
                        destination(for: route)
                    }
            }
            .tabItem {
                Label("찜", systemImage: "heart.fill")
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
        .sheet(item: $rootLoginPresentation) { _ in
            NavigationStack {
                LoginView(apiClient: apiClient, authStore: authStore)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("닫기") {
                                rootLoginPresentation = nil
                            }
                            .accessibilityIdentifier("login-dismiss-button")
                        }
                    }
            }
            .presentationDragIndicator(.visible)
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
                rootLoginPresentation = nil
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
        case .profileEdit:
            ProfileEditView(apiClient: apiClient, authStore: authStore)
        case .login:
            LoginView(apiClient: apiClient, authStore: authStore)
        }
    }

    private func routeToLogin(for tab: RootTab) {
        rootLoginPresentation = RootLoginPresentation(requestedTab: tab)
        tabSelection.loginRouteDidOpen(for: tab)
    }

    private func removeLoginRoutes() {
        favoritesNavigationPath.removeAll { $0 == .login }
        createNavigationPath.removeAll { $0 == .login }
        profileNavigationPath.removeAll { $0 == .login }
    }
}
