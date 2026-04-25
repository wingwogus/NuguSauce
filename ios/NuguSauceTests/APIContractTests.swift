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

    func testBackendClientBuildsRecipeListRequest() async throws {
        URLProtocolTestTransport.responseData = """
        {
          "success": true,
          "data": [
            {
              "id": 1,
              "title": "건희 소스",
              "description": "고소하고 매콤한 인기 조합",
              "imageUrl": null,
              "authorType": "CURATED",
              "visibility": "VISIBLE",
              "ratingSummary": { "averageRating": 4.7, "reviewCount": 18 },
              "reviewTags": [{ "id": 1, "name": "고소함", "count": 12 }],
              "createdAt": "2026-04-25T00:00:00Z"
            }
          ],
          "error": null
        }
        """.data(using: .utf8)!
        URLProtocolTestTransport.statusCode = 200
        URLProtocolTestTransport.lastRequest = nil

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolTestTransport.self]
        let session = URLSession(configuration: configuration)
        let authStore = ContractTestAuthSessionStore()
        let client = BackendAPIClient(
            configuration: APIConfiguration(baseURL: URL(string: "http://127.0.0.1:8080")!),
            session: session,
            authStore: authStore
        )

        let recipes = try await client.fetchRecipes(
            query: RecipeListQuery(keyword: "건희", tagIDs: [2, 1], ingredientIDs: [13], sort: .rating)
        )

        XCTAssertEqual(recipes.first?.title, "건희 소스")
        let requestURL = try XCTUnwrap(URLProtocolTestTransport.lastRequest?.url)
        XCTAssertEqual(requestURL.path, "/api/v1/recipes")
        let components = try XCTUnwrap(URLComponents(url: requestURL, resolvingAgainstBaseURL: false))
        XCTAssertTrue(components.queryItems?.contains(URLQueryItem(name: "q", value: "건희")) == true)
        XCTAssertTrue(components.queryItems?.contains(URLQueryItem(name: "tagIds", value: "1")) == true)
        XCTAssertTrue(components.queryItems?.contains(URLQueryItem(name: "tagIds", value: "2")) == true)
        XCTAssertTrue(components.queryItems?.contains(URLQueryItem(name: "ingredientIds", value: "13")) == true)
        XCTAssertTrue(components.queryItems?.contains(URLQueryItem(name: "sort", value: "rating")) == true)
    }
}

private final class ContractTestAuthSessionStore: AuthSessionStoreProtocol {
    private(set) var currentSession: AuthSession? = AuthSession(
        displayName: "테스터",
        accessToken: "real-access-token",
        refreshToken: "real-refresh-token"
    )

    var isAuthenticated: Bool { currentSession != nil }
    var accessToken: String? { currentSession?.accessToken }

    func restore() {}

    func saveSession(accessToken: String, refreshToken: String?, displayName: String?) {
        currentSession = AuthSession(displayName: displayName ?? "테스터", accessToken: accessToken, refreshToken: refreshToken)
    }

    func clear() {
        currentSession = nil
    }
}

private final class URLProtocolTestTransport: URLProtocol {
    static var responseData = Data()
    static var statusCode = 200
    static var lastRequest: URLRequest?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.lastRequest = request
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: Self.statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseData)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
