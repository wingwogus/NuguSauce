import SwiftUI

struct SauceChip: View {
    let title: String
    var isSelected = false
    var icon: String?

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.caption.weight(.bold))
            }
            Text(title)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(isSelected ? SauceColor.onPrimary : SauceColor.onSurfaceVariant)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(isSelected ? SauceColor.primaryContainer : SauceColor.chip)
        .clipShape(Capsule())
    }
}

struct RatingBadge: View {
    let rating: Double

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .foregroundStyle(SauceColor.secondary)
            Text(String(format: "%.1f", rating))
                .font(.caption.weight(.bold))
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
                .font(.system(size: 16, weight: .bold))
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
            .scaledToFit()
            .padding(size * 0.08)
            .frame(width: size, height: size)
            .background(SauceColor.chip)
            .clipShape(Circle())
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

struct SauceStatusBanner: View {
    let message: String
    var isError = true

    var body: some View {
        Text(message)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isError ? SauceColor.primaryContainer : SauceColor.onSurfaceVariant)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(isError ? SauceColor.redTint : SauceColor.surfaceContainerLow)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct SauceScreenTitle: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(.largeTitle.weight(.black))
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
                    .font(.subheadline)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit(action)
            } else {
                Text(placeholder)
                    .font(.subheadline)
                    .foregroundStyle(SauceColor.muted)
            }

            Spacer()

            Button(action: action) {
                Text("검색")
                    .font(.caption.weight(.bold))
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
        .shadow(color: SauceColor.cardShadow.opacity(0.04), radius: 16, x: 0, y: 8)
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

    private var gradientColors: [Color] {
        switch recipeID % 4 {
        case 0:
            return [Color(red: 0.98, green: 0.82, blue: 0.35), Color(red: 0.74, green: 0.12, blue: 0.05)]
        case 1:
            return [Color(red: 0.98, green: 0.62, blue: 0.22), Color(red: 0.34, green: 0.12, blue: 0.06)]
        case 2:
            return [Color(red: 0.96, green: 0.83, blue: 0.50), Color(red: 0.76, green: 0.62, blue: 0.35)]
        default:
            return [Color(red: 0.28, green: 0.50, blue: 0.32), Color(red: 0.11, green: 0.18, blue: 0.12)]
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle()
                .fill(SauceColor.onPrimary.opacity(0.22))
                .frame(width: height * 0.72)
                .blur(radius: 8)
                .offset(y: height * 0.12)
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(SauceColor.onPrimary.opacity(0.26))
                .frame(width: height * 0.48, height: height * 0.64)
                .overlay(alignment: .top) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(SauceColor.onPrimary.opacity(0.55))
                        .frame(width: height * 0.40, height: height * 0.08)
                        .offset(y: -8)
                }
                .overlay {
                    VStack(spacing: 8) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(SauceColor.onPrimary.opacity(0.88))
                        Text("SAUCE")
                            .font(.caption.weight(.black))
                            .foregroundStyle(SauceColor.onPrimary.opacity(0.9))
                    }
                }
                .shadow(color: SauceColor.cardShadow.opacity(0.18), radius: 18, x: 0, y: 10)
        }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                RecipeImage(imageURL: recipe.imageUrl, recipeID: recipe.id, height: 240)
                RatingBadge(rating: recipe.ratingSummary.averageRating)
                    .padding(14)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text(recipe.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(SauceColor.onSurface)
                Text(recipe.description)
                    .font(.subheadline)
                    .foregroundStyle(SauceColor.onSurfaceVariant)
                    .lineLimit(2)

                HStack {
                    ForEach(recipe.reviewTags.prefix(3)) { tag in
                        SauceChip(title: tag.name)
                    }
                }

                HStack {
                    Label("\(recipe.ratingSummary.reviewCount.formatted())", systemImage: "heart.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(SauceColor.onSurfaceVariant)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(SauceColor.primaryContainer)
                        .frame(width: 36, height: 36)
                        .background(SauceColor.redTint)
                        .clipShape(Circle())
                }
            }
            .padding(18)
        }
        .sauceCard()
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
                        .font(.headline.weight(.bold))
                        .lineLimit(1)
                    Spacer()
                    RatingBadge(rating: recipe.ratingSummary.averageRating)
                }
                Text(recipe.description)
                    .font(.caption)
                    .foregroundStyle(SauceColor.onSurfaceVariant)
                    .lineLimit(1)
                HStack {
                    Circle()
                        .fill(SauceColor.primary)
                        .frame(width: 7, height: 7)
                    Text(recipe.reviewTags.first?.name ?? "태그 없음")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(SauceColor.onSurfaceVariant)
                    Spacer()
                    Label("\(recipe.ratingSummary.reviewCount)", systemImage: "hand.thumbsup.fill")
                        .font(.caption2)
                        .foregroundStyle(SauceColor.onSurfaceVariant)
                }
            }
        }
        .padding(14)
        .sauceCard(cornerRadius: 14)
    }
}
