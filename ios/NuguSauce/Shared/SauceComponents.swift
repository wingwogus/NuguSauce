import SwiftUI

struct SauceChip: View {
    let title: String
    var isSelected = false
    var icon: String?

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(SauceTypography.badge(.bold))
            }
            Text(title)
                .font(SauceTypography.badge(.semibold))
        }
        .foregroundStyle(isSelected ? SauceColor.onPrimary : SauceColor.onSurfaceVariant)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(isSelected ? SauceColor.primaryContainer : SauceColor.chip)
        .clipShape(Capsule())
    }
}

struct RecipeTasteTag: View {
    let title: String

    var body: some View {
        Text(title)
            .font(SauceTypography.badge(.bold))
            .foregroundStyle(SauceColor.onSurface)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(SauceColor.redTint)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

struct RecipeMiniTagRow: View {
    private let titles: [String]

    init(recipe: RecipeSummaryDTO) {
        titles = recipe.reviewTagTitles
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(titles.indices, id: \.self) { index in
                RecipeTasteTag(title: titles[index])
            }
        }
        .lineLimit(1)
    }
}

struct RecipeCardMetricRow: View {
    let recipe: RecipeSummaryDTO
    var starColor = SauceColor.secondary
    var favoriteColor = SauceColor.primaryContainer

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .foregroundStyle(starColor)
                Text(recipe.ratingReviewText)
            }

            HStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(favoriteColor)
                Text("\(recipe.displayFavoriteCount.formatted())")
            }
        }
        .lineLimit(1)
    }
}

struct RatingBadge: View {
    let rating: Double

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .foregroundStyle(SauceColor.secondary)
            Text(String(format: "%.1f", rating))
                .font(SauceTypography.badge(.bold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(SauceColor.surfaceLowest.opacity(0.92))
        .clipShape(Capsule())
    }
}

struct SauceIconButton: View {
    let systemName: String
    var foreground = SauceColor.primaryContainer
    var background = SauceColor.surfaceLowest.opacity(0.9)
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(SauceTypography.iconSmall(.bold))
                .foregroundStyle(foreground)
                .frame(width: 42, height: 42)
                .background(background)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

struct IngredientArtwork: View {
    let name: String
    let category: String?
    var size: CGFloat = 42

    var body: some View {
        Image(Self.assetName(forName: name, category: category))
            .renderingMode(.original)
            .resizable()
            .interpolation(.medium)
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            .accessibilityHidden(true)
    }

    static func assetName(forName name: String, category: String?) -> String {
        exactAssetNames[normalizedName(name)] ?? categoryAssetName(for: category)
    }

    private static func categoryAssetName(for category: String?) -> String {
        categoryAssetNames[normalizedCategory(category)] ?? "IngredientOther"
    }

    private static func normalizedName(_ name: String) -> String {
        name.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static func normalizedCategory(_ category: String?) -> String {
        category?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
    }

    private static let exactAssetNames = [
        "참기름": "IngredientOil",
        "땅콩소스": "IngredientPeanutSauce",
        "다진 마늘": "IngredientGarlic",
        "고수": "IngredientCilantro",
        "다진 고추": "IngredientChili",
        "해선장": "IngredientHoisinSauce",
        "간장": "IngredientSoySauce",
        "식초": "IngredientVinegar",
        "설탕": "IngredientSugar",
        "파": "IngredientScallion",
        "깨": "IngredientSesameSeeds",
        "고추기름": "IngredientChiliOil",
        "스위트 칠리소스": "IngredientSweetChili",
        "땅콩가루": "IngredientPeanutPowder",
        "고춧가루": "IngredientChiliPowder",
        "볶음 소고기장": "IngredientBeefSauce",
        "마라소스": "IngredientMalaSauce",
        "참깨소스": "IngredientSesameSauce",
        "굴소스": "IngredientOysterSauce",
        "중국식초": "IngredientChineseVinegar",
        "흑식초": "IngredientBlackVinegar",
        "와사비": "IngredientWasabi",
        "레몬즙": "IngredientLemon",
        "소금": "IngredientSalt",
        "맛소금": "IngredientSeasonedSalt",
        "연유": "IngredientCondensedMilk",
        "들깨가루": "IngredientPerillaPowder",
        "양파": "IngredientOnion",
        "태국 고추": "IngredientThaiChili",
        "다진 고기": "IngredientGroundMeat",
        "마라시즈닝": "IngredientMalaSeasoning",
        "청유 훠궈 소스": "IngredientGreenHotpotSauce",
        "버섯소스": "IngredientMushroom",
        "오향 우육": "IngredientFiveSpiceBeef",
        "매운 소고기 소스": "IngredientSpicyBeefSauce",
        "쪽파": "IngredientChives",
        "대파": "IngredientGreenOnion",
        "참깨가루": "IngredientSesamePowder"
    ]

    private static let categoryAssetNames = [
        "sauce_paste": "IngredientSaucePaste",
        "oil": "IngredientOil",
        "vinegar_citrus": "IngredientVinegar",
        "fresh_aromatic": "IngredientFreshAromatic",
        "dry_seasoning": "IngredientDrySeasoning",
        "sweet_dairy": "IngredientSweetDairy",
        "topping_seed": "IngredientToppingSeed",
        "protein": "IngredientProtein",
        "other": "IngredientOther"
    ]
}

enum NuguMascotAsset: String, CaseIterable {
    case red = "NuguMascotRed"
    case yellow = "NuguMascotYellow"
    case green = "NuguMascotGreen"
    case black = "NuguMascotBlack"

    static let profilePlaceholders: [NuguMascotAsset] = [.red, .green, .black, .yellow]

    static func placeholder(for recipeID: Int) -> NuguMascotAsset {
        let assets = Self.allCases
        let index = abs(recipeID % assets.count)
        return assets[index]
    }

    static func profilePlaceholder(identityName: String?, seed: String? = nil) -> NuguMascotAsset {
        if isOfficialNuguSauceIdentity(identityName) {
            return .red
        }

        guard let seed = normalizedSeed(seed) else {
            return profilePlaceholders.randomElement() ?? .red
        }

        let index = stableIndex(for: seed, count: profilePlaceholders.count)
        return profilePlaceholders[index]
    }

    private static func isOfficialNuguSauceIdentity(_ identityName: String?) -> Bool {
        normalizedSeed(identityName)?.caseInsensitiveCompare("NuguSauce") == .orderedSame
    }

    private static func normalizedSeed(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func stableIndex(for seed: String, count: Int) -> Int {
        guard count > 0 else {
            return 0
        }
        let hash = seed.unicodeScalars.reduce(UInt64(14_695_981_039_346_656_037)) { partial, scalar in
            (partial ^ UInt64(scalar.value)) &* 1_099_511_628_211
        }
        return Int(hash % UInt64(count))
    }
}

struct NuguMascotImage: View {
    let asset: NuguMascotAsset

    var body: some View {
        Image(asset.rawValue)
            .renderingMode(.original)
            .resizable()
            .interpolation(.medium)
            .scaledToFit()
    }
}

struct SauceStatusBanner: View {
    let message: String
    var isError = true

    var body: some View {
        Text(message)
            .font(SauceTypography.body(.semibold))
            .foregroundStyle(isError ? SauceColor.primaryContainer : SauceColor.onSurfaceVariant)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(isError ? SauceColor.redTint : SauceColor.surfaceContainerLow)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct LoginGatePlaceholder: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: systemImage)
                .font(SauceTypography.iconLarge(.bold))
                .foregroundStyle(SauceColor.primaryContainer)
                .frame(width: 64, height: 64)
                .background(SauceColor.redTint)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(SauceTypography.sectionTitle())
                    .foregroundStyle(SauceColor.onSurface)
                    .fixedSize(horizontal: false, vertical: true)
                Text(message)
                    .font(SauceTypography.body())
                    .foregroundStyle(SauceColor.onSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)
            }

            NavigationLink(value: AppRoute.login) {
                Label("로그인 화면으로 이동", systemImage: "arrow.right")
                    .frame(maxWidth: .infinity)
            }
            .primarySauceButton()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 28)
        .accessibilityIdentifier("login-gate-placeholder")
    }
}

struct ProfileAvatar: View {
    let imageURL: String?
    var size: CGFloat = 56
    var identityName: String?
    var fallbackSeed: String?
    @State private var retryAttempt = 0
    @State private var retryScheduledForURL: String?
    @State private var fallbackAsset: NuguMascotAsset

    init(
        imageURL: String?,
        size: CGFloat = 56,
        identityName: String? = nil,
        fallbackSeed: String? = nil
    ) {
        self.imageURL = imageURL
        self.size = size
        self.identityName = identityName
        self.fallbackSeed = fallbackSeed
        _fallbackAsset = State(
            initialValue: NuguMascotAsset.profilePlaceholder(identityName: identityName, seed: fallbackSeed)
        )
    }

    var body: some View {
        Group {
            if let imageURL, let url = remoteURL(for: imageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        fallback
                            .onAppear {
                                scheduleRetry(for: imageURL)
                            }
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(SauceColor.surfaceContainerLow)
                    @unknown default:
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .id("\(imageURL ?? "fallback")-\(retryAttempt)")
        .frame(width: size, height: size)
        .background(SauceColor.surfaceLowest)
        .clipShape(Circle())
        .overlay {
            Circle()
                .stroke(SauceColor.surface, lineWidth: max(1, size * 0.035))
        }
        .clipped()
        .onChange(of: imageURL) { _, _ in
            retryAttempt = 0
            retryScheduledForURL = nil
        }
        .onChange(of: identityName) { _, _ in
            updateFallbackAsset()
        }
        .onChange(of: fallbackSeed) { _, _ in
            updateFallbackAsset()
        }
    }

    private var fallback: some View {
        NuguMascotImage(asset: fallbackAsset)
            .padding(size * 0.12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(SauceColor.surfaceLowest)
    }

    private func remoteURL(for imageURL: String) -> URL? {
        guard var components = URLComponents(string: imageURL) else {
            return nil
        }
        if retryAttempt > 0 {
            var queryItems = components.queryItems ?? []
            queryItems.append(URLQueryItem(name: "nugusauceAvatarRetry", value: "\(retryAttempt)"))
            components.queryItems = queryItems
        }
        return components.url
    }

    private func scheduleRetry(for imageURL: String) {
        guard retryAttempt < Self.maxRetryAttempts,
              retryScheduledForURL != imageURL else {
            return
        }
        retryScheduledForURL = imageURL
        let nextAttempt = retryAttempt + 1
        Task {
            try? await Task.sleep(nanoseconds: 700_000_000)
            await MainActor.run {
                guard self.imageURL == imageURL,
                      retryAttempt < nextAttempt else {
                    return
                }
                retryAttempt = nextAttempt
                retryScheduledForURL = nil
            }
        }
    }

    private func updateFallbackAsset() {
        fallbackAsset = NuguMascotAsset.profilePlaceholder(identityName: identityName, seed: fallbackSeed)
    }

    private static let maxRetryAttempts = 3
}

struct SauceScreenTitle: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(SauceTypography.sectionTitle())
                .foregroundStyle(SauceColor.onSurface)
            Spacer()
        }
        .padding(.top, 18)
    }
}

struct SauceSearchBar: View {
    private let placeholder: String
    private let isEditable: Bool
    private let action: () -> Void
    @Binding private var text: String

    init(placeholder: String = "새로운 맛을 찾아보세요...", action: @escaping () -> Void = {}) {
        self.placeholder = placeholder
        self.isEditable = false
        self.action = action
        _text = .constant("")
    }

    init(text: Binding<String>, placeholder: String = "새로운 맛을 찾아보세요...", action: @escaping () -> Void) {
        self.placeholder = placeholder
        self.isEditable = true
        self.action = action
        _text = text
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(SauceColor.onSurfaceVariant)

            if isEditable {
                TextField(placeholder, text: $text)
                    .font(SauceTypography.body())
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit(action)
            } else {
                Text(placeholder)
                    .font(SauceTypography.body())
                    .foregroundStyle(SauceColor.muted)
            }

            Spacer()

            Button(action: action) {
                Text("검색")
                    .font(SauceTypography.badge(.bold))
                    .foregroundStyle(SauceColor.onPrimary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(SauceColor.primaryContainer)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 16)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .background(SauceColor.surfaceLowest)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(SauceColor.outline.opacity(0.16), lineWidth: 1)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !isEditable {
                action()
            }
        }
    }
}

struct SauceArtwork: View {
    let recipeID: Int
    var height: CGFloat = 220

    var body: some View {
        ZStack {
            SauceColor.surfaceContainerLow
            NuguMascotImage(asset: NuguMascotAsset.placeholder(for: recipeID))
                .padding(height * 0.14)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipped()
    }
}

struct RecipeImage: View {
    let imageURL: String?
    let recipeID: Int
    var height: CGFloat = 220

    var body: some View {
        GeometryReader { proxy in
            Group {
                if let imageURL, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            SauceArtwork(recipeID: recipeID, height: height)
                        case .empty:
                            ProgressView()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(SauceColor.surfaceContainerLow)
                        @unknown default:
                            SauceArtwork(recipeID: recipeID, height: height)
                        }
                    }
                } else {
                    SauceArtwork(recipeID: recipeID, height: height)
                }
            }
            .frame(width: proxy.size.width, height: height)
            .clipped()
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipped()
    }
}

struct RecipeCard: View {
    let recipe: RecipeSummaryDTO
    var rank: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                RecipeImage(imageURL: recipe.imageUrl, recipeID: recipe.id, height: Self.imageHeight)
                    .frame(width: Self.cardWidth, height: Self.imageHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                if let rank {
                    RecipeRankOverlay(rank: rank)
                        .padding(.leading, 6)
                        .padding(.top, 4)
                }

                VStack {
                    HStack {
                        Spacer()
                        RecipeFavoriteStateBadge(
                            isFavorite: recipe.isFavorited,
                            size: 28,
                            foreground: SauceColor.primaryContainer,
                            inactiveForeground: SauceColor.onPrimary.opacity(0.88)
                        )
                        .padding(8)
                    }
                    Spacer()
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(recipe.title)
                    .font(SauceTypography.cardTitle())
                    .foregroundStyle(SauceColor.onSurface)
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)

                RecipeCardTagRow(tags: Array(recipe.reviewTags.prefix(3)))

                RecipeCardMetricRow(recipe: recipe)
                    .font(SauceTypography.metric(.bold))
                    .foregroundStyle(SauceColor.onSurfaceVariant)
                    .lineLimit(1)
                    .minimumScaleFactor(0.88)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 10)
            .frame(height: Self.contentHeight, alignment: .topLeading)
        }
        .frame(width: Self.cardWidth, height: Self.cardHeight, alignment: .topLeading)
        .contentShape(Rectangle())
    }

    static let cardWidth: CGFloat = 156
    private static var cardHeight: CGFloat {
        imageHeight + contentHeight
    }
    private static let imageHeight: CGFloat = 142
    private static let contentHeight: CGFloat = 92
}

private struct RecipeCardTagRow: View {
    let tags: [ReviewTagDTO]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(tags) { tag in
                Text(tag.name)
                    .font(SauceTypography.micro(.bold))
                    .foregroundStyle(SauceColor.onSurface)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .background(SauceColor.redTint)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            }
        }
        .frame(width: RecipeCard.cardWidth, height: 18, alignment: .leading)
        .clipped()
    }
}

private struct RecipeRankOverlay: View {
    let rank: Int

    var body: some View {
        ZStack(alignment: .topLeading) {
            rankText
                .foregroundStyle(SauceColor.onSurface)
                .offset(x: -1.4, y: 0)
            rankText
                .foregroundStyle(SauceColor.onSurface)
                .offset(x: 1.4, y: 0)
            rankText
                .foregroundStyle(SauceColor.onSurface)
                .offset(x: 0, y: -1.4)
            rankText
                .foregroundStyle(SauceColor.onSurface)
                .offset(x: 0, y: 1.4)
            rankText
                .foregroundStyle(SauceColor.surfaceLowest)
        }
        .frame(width: 52, height: 56, alignment: .topLeading)
        .accessibilityLabel("인기 순위 \(rank)")
    }

    private var rankText: some View {
        Text("\(rank)")
            .font(SauceTypography.rankDisplay())
            .monospacedDigit()
    }
}

struct RecipeFavoriteStateBadge: View {
    let isFavorite: Bool
    var size: CGFloat = 30
    var foreground: Color = SauceColor.primaryContainer
    var inactiveForeground: Color = SauceColor.onSurfaceVariant

    var body: some View {
        Image(systemName: isFavorite ? "heart.fill" : "heart")
            .font(SauceTypography.favoriteIcon(size: size, isActive: isFavorite))
            .foregroundStyle(isFavorite ? foreground : inactiveForeground)
            .frame(width: size, height: size)
            .accessibilityLabel(isFavorite ? "찜한 소스" : "찜하지 않은 소스")
    }
}

extension RecipeSummaryDTO {
    var reviewTagTitles: [String] {
        reviewTags.prefix(2).map(\.name)
    }
}

struct CompactRecipeRow: View {
    let recipe: RecipeSummaryDTO

    var body: some View {
        HStack(spacing: 14) {
            RecipeImage(imageURL: recipe.imageUrl, recipeID: recipe.id, height: 74)
                .frame(width: 92)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(recipe.title)
                        .font(SauceTypography.cardTitle(.bold))
                        .lineLimit(1)
                    Spacer()
                    RecipeCardMetricRow(recipe: recipe)
                        .font(SauceTypography.metric(.bold))
                        .foregroundStyle(SauceColor.onSurface)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
                HStack(spacing: 8) {
                    RecipeMiniTagRow(recipe: recipe)
                    Spacer()
                }
            }
        }
        .padding(14)
        .sauceCard(cornerRadius: 14)
    }
}
