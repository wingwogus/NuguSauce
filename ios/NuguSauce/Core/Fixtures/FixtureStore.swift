import Foundation

struct FixtureRecipeSeed: Identifiable, Equatable {
    let id: Int
    let title: String
    let description: String
    let tips: String
    let authorType: AuthorType
    let visibility: RecipeVisibility
    let tagIDs: [Int]
    let ingredientSeeds: [FixtureIngredientAmount]
    let createdAt: String
}

struct FixtureIngredientAmount: Equatable {
    let ingredientID: Int
    let amount: Double
    let unit: String
    let ratio: Double?
}

struct FixtureFavorite: Equatable {
    let recipeID: Int
    let memberUserID: Int
}

struct FixtureStore {
    let ingredients: [IngredientDTO]
    let tags: [TagDTO]
    let curatedRecipes: [FixtureRecipeSeed]
    let userRecipes: [FixtureRecipeSeed]
    let reviews: [RecipeReviewDTO]
    let favorites: [FixtureFavorite]

    static let preview = FixtureStore(
        ingredients: [
            IngredientDTO(id: 1, name: "참기름", category: "oil"),
            IngredientDTO(id: 2, name: "땅콩소스", category: "sauce"),
            IngredientDTO(id: 3, name: "다진 마늘", category: "aromatic"),
            IngredientDTO(id: 4, name: "고수", category: "herb"),
            IngredientDTO(id: 5, name: "다진 고추", category: "spicy"),
            IngredientDTO(id: 7, name: "간장", category: "sauce"),
            IngredientDTO(id: 8, name: "식초", category: "acid"),
            IngredientDTO(id: 10, name: "파", category: "aromatic"),
            IngredientDTO(id: 12, name: "고추기름", category: "spicy"),
            IngredientDTO(id: 13, name: "스위트 칠리소스", category: "sauce"),
            IngredientDTO(id: 14, name: "땅콩가루", category: "topping"),
            IngredientDTO(id: 18, name: "참깨소스", category: "sauce")
        ],
        tags: [
            TagDTO(id: 1, name: "고소함"),
            TagDTO(id: 2, name: "매콤함"),
            TagDTO(id: 3, name: "달달함"),
            TagDTO(id: 4, name: "상큼함"),
            TagDTO(id: 7, name: "감칠맛"),
            TagDTO(id: 9, name: "마늘향"),
            TagDTO(id: 12, name: "유명조합"),
            TagDTO(id: 14, name: "셀럽추천")
        ],
        curatedRecipes: [
            FixtureRecipeSeed(
                id: 1,
                title: "건희 소스 오리지널",
                description: "고소하고 매콤한 대표 하이디라오 조합",
                tips: "땅콩소스를 먼저 풀고 고추기름은 마지막에 둘러 향을 살려주세요.",
                authorType: .curated,
                visibility: .visible,
                tagIDs: [1, 2, 3, 12, 14],
                ingredientSeeds: [
                    FixtureIngredientAmount(ingredientID: 2, amount: 1.0, unit: "스푼", ratio: nil),
                    FixtureIngredientAmount(ingredientID: 13, amount: 2.5, unit: "스푼", ratio: nil),
                    FixtureIngredientAmount(ingredientID: 3, amount: 0.5, unit: "스푼", ratio: nil),
                    FixtureIngredientAmount(ingredientID: 12, amount: 1.0, unit: "티스푼", ratio: nil)
                ],
                createdAt: "2026-04-25T00:00:00Z"
            ),
            FixtureRecipeSeed(
                id: 2,
                title: "건희 소스 2025 버전",
                description: "진한 감칠맛과 고소함을 강화한 최신 조합",
                tips: "단맛을 줄이고 싶다면 스위트 칠리소스를 반 스푼만 넣어주세요.",
                authorType: .curated,
                visibility: .visible,
                tagIDs: [1, 2, 7, 12, 14],
                ingredientSeeds: [
                    FixtureIngredientAmount(ingredientID: 2, amount: 1.0, unit: "스푼", ratio: nil),
                    FixtureIngredientAmount(ingredientID: 13, amount: 1.0, unit: "스푼", ratio: nil),
                    FixtureIngredientAmount(ingredientID: 10, amount: 1.0, unit: "스푼", ratio: nil),
                    FixtureIngredientAmount(ingredientID: 3, amount: 1.0, unit: "스푼", ratio: nil)
                ],
                createdAt: "2026-04-25T00:10:00Z"
            ),
            FixtureRecipeSeed(
                id: 3,
                title: "마크 소스",
                description: "땅콩, 간장, 굴소스 기반의 묵직한 조합",
                tips: "간장 비율이 높아 짠맛이 강하면 식초를 한 티스푼 더해 균형을 맞추세요.",
                authorType: .curated,
                visibility: .visible,
                tagIDs: [1, 2, 7, 14],
                ingredientSeeds: [
                    FixtureIngredientAmount(ingredientID: 2, amount: 2.0, unit: "스푼", ratio: nil),
                    FixtureIngredientAmount(ingredientID: 3, amount: 1.5, unit: "스푼", ratio: nil),
                    FixtureIngredientAmount(ingredientID: 7, amount: 2.0, unit: "스푼", ratio: nil),
                    FixtureIngredientAmount(ingredientID: 14, amount: 0.3, unit: "스푼", ratio: nil)
                ],
                createdAt: "2026-04-25T00:20:00Z"
            ),
            FixtureRecipeSeed(
                id: 5,
                title: "숨김 처리된 샘플",
                description: "공개 목록에서 제외되어야 하는 fixture",
                tips: "숨김 fixture",
                authorType: .curated,
                visibility: .hidden,
                tagIDs: [2],
                ingredientSeeds: [
                    FixtureIngredientAmount(ingredientID: 5, amount: 1.0, unit: "스푼", ratio: nil)
                ],
                createdAt: "2026-04-25T00:30:00Z"
            )
        ],
        userRecipes: [
            FixtureRecipeSeed(
                id: 101,
                title: "마늘 듬뿍 고소 소스",
                description: "마늘 향이 강한 사용자 조합",
                tips: "참기름을 먼저 넣고 마늘을 충분히 섞어주세요.",
                authorType: .user,
                visibility: .visible,
                tagIDs: [1, 9],
                ingredientSeeds: [
                    FixtureIngredientAmount(ingredientID: 3, amount: 1.5, unit: "스푼", ratio: nil),
                    FixtureIngredientAmount(ingredientID: 1, amount: 1.0, unit: "스푼", ratio: nil),
                    FixtureIngredientAmount(ingredientID: 2, amount: 0.5, unit: "스푼", ratio: nil)
                ],
                createdAt: "2026-04-25T01:00:00Z"
            ),
            FixtureRecipeSeed(
                id: 102,
                title: "고수 상큼 소스",
                description: "고수와 식초 중심의 산뜻한 조합",
                tips: "고수는 마지막에 올려 향을 살려주세요.",
                authorType: .user,
                visibility: .visible,
                tagIDs: [4],
                ingredientSeeds: [
                    FixtureIngredientAmount(ingredientID: 4, amount: 1.0, unit: "스푼", ratio: nil),
                    FixtureIngredientAmount(ingredientID: 8, amount: 1.0, unit: "스푼", ratio: nil),
                    FixtureIngredientAmount(ingredientID: 7, amount: 0.5, unit: "스푼", ratio: nil)
                ],
                createdAt: "2026-04-25T01:10:00Z"
            )
        ],
        reviews: [
            RecipeReviewDTO(
                id: 1001,
                recipeId: 1,
                rating: 5,
                text: "단짠 균형이 좋아서 계속 손이 감",
                tasteTags: [ReviewTagDTO(id: 1, name: "고소함", count: nil), ReviewTagDTO(id: 12, name: "유명조합", count: nil)],
                createdAt: "2026-04-25T01:00:00Z"
            ),
            RecipeReviewDTO(
                id: 1002,
                recipeId: 1,
                rating: 4,
                text: "고소하지만 살짝 더 매워도 좋음",
                tasteTags: [ReviewTagDTO(id: 1, name: "고소함", count: nil), ReviewTagDTO(id: 2, name: "매콤함", count: nil)],
                createdAt: "2026-04-25T02:00:00Z"
            )
        ],
        favorites: [
            FixtureFavorite(recipeID: 1, memberUserID: 1),
            FixtureFavorite(recipeID: 2, memberUserID: 1)
        ]
    )
}
