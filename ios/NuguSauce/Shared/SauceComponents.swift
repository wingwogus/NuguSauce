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
        .foregroundStyle(isSelected ? .white : SauceColor.onSurfaceVariant)
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
        .background(.white.opacity(0.92))
        .clipShape(Capsule())
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
                .fill(.white.opacity(0.22))
                .frame(width: height * 0.72)
                .blur(radius: 8)
                .offset(y: height * 0.12)
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(0.26))
                .frame(width: height * 0.48, height: height * 0.64)
                .overlay(alignment: .top) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.white.opacity(0.55))
                        .frame(width: height * 0.40, height: height * 0.08)
                        .offset(y: -8)
                }
                .overlay {
                    VStack(spacing: 8) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(.white.opacity(0.88))
                        Text("SAUCE")
                            .font(.caption.weight(.black))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
                .shadow(color: .black.opacity(0.18), radius: 18, x: 0, y: 10)
        }
        .frame(height: height)
        .clipped()
    }
}

struct RecipeCard: View {
    let recipe: RecipeSummaryDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                SauceArtwork(recipeID: recipe.id, height: 240)
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
                    Image(systemName: "plus")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(SauceColor.primary)
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
            SauceArtwork(recipeID: recipe.id, height: 74)
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
                    Text(recipe.reviewTags.first?.name ?? "추천")
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
