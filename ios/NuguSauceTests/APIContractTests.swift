import XCTest
@testable import NuguSauce

final class APIContractTests: XCTestCase {
    func testEnvelopeSuccessDecodes() throws {
        let json = """
        {
          "success": true,
          "data": {
            "id": 1,
            "title": "건희 소스",
            "description": "고소하고 매콤한 인기 조합",
            "imageUrl": null,
            "authorType": "CURATED",
            "visibility": "VISIBLE",
            "ratingSummary": { "averageRating": 4.7, "reviewCount": 18 },
            "reviewTags": [{ "id": 1, "name": "고소함", "count": 12 }],
            "createdAt": "2026-04-25T00:00:00Z"
          },
          "error": null
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(ApiEnvelope<RecipeSummaryDTO>.self, from: json)

        XCTAssertTrue(envelope.success)
        XCTAssertEqual(envelope.data?.title, "건희 소스")
        XCTAssertNil(envelope.error)
    }

    func testEnvelopeFailureDecodesStableErrorCode() throws {
        let json = """
        {
          "success": false,
          "data": null,
          "error": {
            "code": "RECIPE_005",
            "message": "recipe.duplicate_review",
            "detail": null
          }
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(ApiEnvelope<EmptyResponse>.self, from: json)

        XCTAssertFalse(envelope.success)
        XCTAssertEqual(envelope.error?.code, ApiErrorCode.duplicateReview)
    }

    func testCreateRecipeRequestDoesNotEncodeTasteClassificationFields() throws {
        let request = CreateRecipeRequestDTO(
            title: "내 소스",
            description: "고소하고 살짝 매운 조합",
            imageUrl: nil,
            tips: "땅콩소스를 먼저 푼다",
            ingredients: [
                CreateRecipeIngredientRequestDTO(ingredientId: 1, amount: 1.0, unit: "스푼", ratio: nil)
            ]
        )

        let data = try JSONEncoder().encode(request)
        let encoded = String(decoding: data, as: UTF8.self)

        XCTAssertFalse(encoded.contains("spiceLevel"))
        XCTAssertFalse(encoded.contains("richnessLevel"))
        XCTAssertFalse(encoded.contains("tagIds"))
    }
}
