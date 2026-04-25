import SwiftUI

struct SearchView: View {
    let apiClient: APIClientProtocol
    let authStore: AuthSessionStoreProtocol
    @StateObject private var viewModel: SearchViewModel

    init(apiClient: APIClientProtocol, authStore: AuthSessionStoreProtocol) {
        self.apiClient = apiClient
        self.authStore = authStore
        _viewModel = StateObject(wrappedValue: SearchViewModel(apiClient: apiClient))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("검색")
                    .font(.largeTitle.weight(.black))
                    .padding(.top, 18)

                searchField
                sortPicker
                tagSection
                ingredientSection
                results
            }
            .padding(.horizontal, SauceSpacing.screen)
            .padding(.bottom, 42)
        }
        .background(SauceColor.surface.ignoresSafeArea())
        .navigationDestination(for: AppRoute.self) { route in
            switch route {
            case .recipeDetail(let id):
                RecipeDetailView(recipeID: id, apiClient: apiClient, authStore: authStore)
            case .publicProfile:
                PublicProfilePlaceholderView()
            case .loginRequired:
                LoginRequiredView(authStore: authStore)
            }
        }
        .task {
            await viewModel.load()
        }
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(SauceColor.onSurfaceVariant)
            TextField("소스, 재료, 맛 검색", text: $viewModel.query)
                .textInputAutocapitalization(.never)
                .onSubmit {
                    Task {
                        try? await viewModel.search()
                    }
                }
            Button("검색") {
                Task {
                    try? await viewModel.search()
                }
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(SauceColor.primaryContainer)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(12)
        .sauceCard(cornerRadius: 14)
    }

    private var sortPicker: some View {
        Picker("정렬", selection: $viewModel.sort) {
            ForEach(RecipeSort.allCases) { sort in
                Text(sort.label).tag(sort)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: viewModel.sort) { _, _ in
            Task {
                try? await viewModel.search()
            }
        }
    }

    private var tagSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("맛별 필터")
                .font(.headline.weight(.bold))
            FlexibleChips(items: viewModel.tags) { tag in
                Button {
                    viewModel.toggleTag(tag)
                    Task {
                        try? await viewModel.search()
                    }
                } label: {
                    SauceChip(title: tag.name, isSelected: viewModel.selectedTagIDs.contains(tag.id))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var ingredientSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("재료별 필터")
                .font(.headline.weight(.bold))
            FlexibleChips(items: viewModel.ingredients.prefix(10).map { $0 }) { ingredient in
                Button {
                    viewModel.toggleIngredient(ingredient)
                    Task {
                        try? await viewModel.search()
                    }
                } label: {
                    SauceChip(title: ingredient.name, isSelected: viewModel.selectedIngredientIDs.contains(ingredient.id))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var results: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("검색 결과")
                .font(.headline.weight(.bold))
            ForEach(viewModel.results) { recipe in
                NavigationLink(value: AppRoute.recipeDetail(recipe.id)) {
                    CompactRecipeRow(recipe: recipe)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct FlexibleChips<Item: Identifiable, Content: View>: View {
    let items: [Item]
    @ViewBuilder let content: (Item) -> Content

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(items) { item in
                content(item)
            }
        }
    }
}
