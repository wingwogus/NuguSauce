# NuguSauce

해디라오 소스 조합을 탐색하고, 직접 만든 조합을 올리고, 다른 사용자의 평가와 리뷰를 확인할 수 있는 커뮤니티형 iOS 앱의 초기 계획 저장소다.

## Current Direction

- 단일 레포에 `backend/`, `ios/`, `ops/`를 둔다.
- 백엔드는 `/Users/wingwogus/IdeaProjects/springboot-kotlin-initial-template`의 `auth-kakao-sdk-oidc-app` 브랜치를 출발점으로 삼는다.
- 개발 방식은 하네스 엔지니어링 기준으로 잡는다. 즉, 기능 구현보다 먼저 계약, 시드 데이터, 핵심 시나리오, 검증 자동화를 만든다.
- 앱 구조는 `/Users/wingwogus/Projects/MiruMiru/ios`와 유사한 `SwiftUI + Xcode project + Tests/UITests` 형태를 우선 따른다.

## Planned Repository Layout

```text
.
├── backend/   # Kotlin + Spring Boot 멀티모듈 API
├── ios/       # SwiftUI 기반 iOS 앱
├── ops/       # 배포/운영/관측성/로컬 인프라
└── .omx/plans # PRD와 테스트 스펙
```

## Planning Artifacts

- [PRD](./.omx/plans/prd-nugusauce-v0.md)
- [Test Spec](./.omx/plans/test-spec-nugusauce-v0.md)
- [Kakao iOS Auth Decision](./.omx/plans/auth-decision-kakao-ios-v0.md)
