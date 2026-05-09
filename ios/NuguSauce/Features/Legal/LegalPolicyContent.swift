import Foundation

enum LegalPolicyType: String, CaseIterable, Identifiable {
    case termsOfService = "terms_of_service"
    case privacyPolicy = "privacy_policy"
    case contentPolicy = "content_policy"

    var id: String {
        rawValue
    }

    var defaultTitle: String {
        switch self {
        case .termsOfService:
            return "서비스 이용약관"
        case .privacyPolicy:
            return "개인정보 처리방침"
        case .contentPolicy:
            return "콘텐츠/사진 권리 정책"
        }
    }
}

struct LegalPolicyDocument: Equatable, Identifiable {
    let policyType: LegalPolicyType
    let version: String
    let title: String
    let effectiveDate: String
    let sourceURL: URL?
    let markdownBody: String

    var id: String {
        "\(policyType.rawValue):\(version)"
    }
}

enum LegalPolicyContent {
    static let missingDocumentMessage = "앱에서 확인할 수 없는 약관 버전입니다. 최신 버전으로 업데이트한 뒤 다시 시도해주세요."

    static func document(for policy: ConsentPolicyDTO, bundle: Bundle = .main) -> LegalPolicyDocument? {
        guard let policyType = LegalPolicyType(rawValue: policy.policyType) else {
            return nil
        }

        let resourceName = "legal_\(policy.policyType)_\(policy.version)"
        guard let url = resourceURL(named: resourceName, bundle: bundle) else {
            return nil
        }

        guard let rawMarkdown = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }

        let parsed = parse(rawMarkdown)
        guard parsed.metadata["policy_type"] == policy.policyType,
              parsed.metadata["version"] == policy.version else {
            return nil
        }

        return LegalPolicyDocument(
            policyType: policyType,
            version: policy.version,
            title: parsed.metadata["title"] ?? policy.title,
            effectiveDate: parsed.metadata["effective_date"] ?? policy.activeFrom,
            sourceURL: parsed.metadata["source_url"].flatMap(URL.init(string:)),
            markdownBody: parsed.body
        )
    }

    static func canDisplayAllMissingPolicies(in status: ConsentStatusDTO, bundle: Bundle = .main) -> Bool {
        missingLocalDocuments(in: status, bundle: bundle).isEmpty
    }

    static func missingLocalDocuments(in status: ConsentStatusDTO, bundle: Bundle = .main) -> [ConsentPolicyDTO] {
        status.missingPolicies.filter { policy in
            policy.required && document(for: policy, bundle: bundle) == nil
        }
    }

    static func documents(for status: ConsentStatusDTO, bundle: Bundle = .main) -> [LegalPolicyDocument] {
        status.missingPolicies.compactMap { document(for: $0, bundle: bundle) }
    }

    private static func parse(_ rawMarkdown: String) -> (metadata: [String: String], body: String) {
        let markdown = rawMarkdown.replacingOccurrences(of: "\r\n", with: "\n")
        guard markdown.hasPrefix("---\n") else {
            return ([:], markdown.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        let metadataStart = markdown.index(markdown.startIndex, offsetBy: 4)
        guard let metadataEnd = markdown.range(of: "\n---\n", range: metadataStart..<markdown.endIndex) else {
            return ([:], markdown.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        let metadataText = String(markdown[metadataStart..<metadataEnd.lowerBound])
        let body = String(markdown[metadataEnd.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        let metadata = metadataText
            .split(separator: "\n")
            .reduce(into: [String: String]()) { result, line in
                let parts = line.split(separator: ":", maxSplits: 1)
                guard parts.count == 2 else {
                    return
                }
                result[String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)] =
                    String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            }

        return (metadata, body)
    }

    private static func resourceURL(named resourceName: String, bundle: Bundle) -> URL? {
        let candidates = [bundle, Bundle.main] + Bundle.allBundles + Bundle.allFrameworks
        var seenBundleIDs = Set<String>()
        for candidate in candidates {
            let key = candidate.bundleURL.absoluteString
            guard seenBundleIDs.insert(key).inserted else {
                continue
            }
            if let url = candidate.url(forResource: resourceName, withExtension: "md") {
                return url
            }
        }
        return nil
    }
}
