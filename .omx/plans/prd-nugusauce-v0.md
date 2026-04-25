# NuguSauce PRD v0

## 1. Product Summary

NuguSauce는 해디라오 스타일 소스 조합을 기록하고 공유하는 커뮤니티형 iOS 앱이다.

핵심 경험은 세 가지다.

- 이미 유명한 조합을 빠르게 찾는다.
- 내가 만든 조합을 사진, 비율, 설명과 함께 올린다.
- 다른 사용자가 별점과 리뷰로 조합 품질을 검증한다.

## 2. Problem

현재 해디라오 소스 조합 정보는 숏폼, 블로그, 커뮤니티 댓글에 흩어져 있다.

- 조합 정보가 구조화되어 있지 않다.
- 실제로 맛있었는지 검증이 어렵다.
- 매장 재료 기준으로 다시 만들기 어렵다.
- 저장, 비교, 재사용 흐름이 약하다.

## 3. Target Users

- 처음 가는 사람: 실패 확률이 낮은 유명 조합이 필요하다.
- 반복 방문자: 자신만의 레시피를 저장하고 공유하고 싶다.
- 소스 덕후/리뷰어: 조합 실험과 평가를 즐긴다.

## 4. Success Criteria For MVP

- 로그인 없이도 유명 조합 목록과 상세를 볼 수 있다.
- 카카오 로그인 후 조합을 등록할 수 있다.
- 별점과 텍스트 리뷰를 남길 수 있다.
- 한 조합의 평균 평점, 리뷰 수, 최근 반응을 볼 수 있다.
- 운영자가 부적절한 게시물을 숨길 수 있다.

## 5. MVP Scope

### In

- 유명 조합 큐레이션 목록
- 조합 상세 페이지
- 카카오 OAuth 로그인
- 사용자 조합 등록
- 조합별 별점 및 리뷰
- 태그/재료 기반 검색과 필터
- 간단한 신고 또는 숨김 처리용 운영 기능

### Out

- 영상 업로드
- 실시간 채팅
- 추천 알고리즘 고도화
- 레벨/배지 시스템
- 매장별 재고 연동

## 6. Recommended Product Shape

### Core entities

- `User`
- `SauceRecipe`
- `RecipeIngredient`
- `RecipeReview`
- `RecipeRatingSummary`
- `RecipeTag`
- `RecipeReport`
- `CuratedRecipeCollection`

### Key fields

`SauceRecipe`

- title
- description
- spice level
- richness level
- ingredients with amount or ratio
- tips
- author type: curated or user
- visibility status

`RecipeReview`

- rating 1..5
- text review
- taste tags
- created by

## 7. Monorepo Structure

단일 레포 안에 `backend`, `ios`, `ops`를 두는 방향이 맞다.

이 앱은 인증, 네이티브 앱 경험, 리뷰 커뮤니티, 배포 구성이 서로 밀접하게 묶여 있으므로 저장소를 분리할 이유가 아직 없다.

추천 구조는 아래와 같다.

```text
.
├── backend/
│   ├── api/
│   ├── application/
│   ├── domain/
│   └── README.md
├── ios/
│   ├── NuguSauce.xcodeproj
│   ├── NuguSauce/
│   │   ├── App/
│   │   ├── Core/
│   │   ├── Features/
│   │   ├── Shared/
│   │   └── Resources/
│   ├── NuguSauceTests/
│   └── NuguSauceUITests/
├── ops/
│   ├── docker/
│   ├── deploy/
│   ├── monitoring/
│   └── README.md
└── .github/workflows/
```

### Repo decisions

- `backend`는 템플릿 기반 멀티모듈 유지
- `ios`는 SwiftUI 단일 앱 타깃으로 시작
- `ops`는 로컬 개발용 `docker-compose`와 배포용 매니페스트를 함께 관리

MiruMiru처럼 `ios/` 아래에 `App`, `Core`, `Features`, `Shared`, `Resources`, `Tests`, `UITests`를 두는 구조가 현재 요구사항에 가장 잘 맞는다.

## 7.1 iOS app recommendation

초기 iOS 앱 구조는 아래처럼 잡는 것을 추천한다.

- `App`: 앱 엔트리, 탭 구조, 라우팅, 앱 라이프사이클
- `Core`: 네트워킹, 인증, Keychain, 환경 설정
- `Features`: Home, RecipeList, RecipeDetail, CreateRecipe, Reviews, Auth
- `Shared`: 공통 UI 컴포넌트, 디자인 토큰, 포맷터
- `Resources`: asset, color, font, plist, config

초기에는 모듈 분리보다 단일 Xcode project 안의 폴더 구조 정리가 낫다.

- 장점: 부트스트랩이 빠르다.
- 장점: 작은 팀에서 refactor 비용이 낮다.
- 단점: 커지면 경계가 느슨해질 수 있다.

이 단점은 `Features`와 `Core` 경계를 강하게 지키는 것으로 초기에 충분히 제어 가능하다.

## 8. Backend Strategy

## Base template candidate

로컬 확인 기준, 템플릿 후보는 다음 레포다.

- path: `/Users/wingwogus/IdeaProjects/springboot-kotlin-initial-template`
- recommended branch: `auth-kakao-sdk-oidc-app`

확인된 사실:

- `main`, `auth-foundation`, `auth-oauth-addon`, `auth-kakao-sdk-oidc-app` 브랜치가 있다.
- `auth-kakao-sdk-oidc-app` 브랜치에는 Kakao SDK 기반 OIDC 앱 로그인, ID token 검증, nonce replay 방지, 관련 테스트가 이미 있다.
- 구조는 `api`, `application`, `domain`, `batch` 멀티모듈이다.

## Import recommendation

초기 NuguSauce에는 아래 순서가 좋다.

1. 템플릿 레포에서 `auth-kakao-sdk-oidc-app` 기준으로 새 브랜치를 만든다.
2. 서비스 공통 기능이 아닌 샘플 성격 코드를 정리한다.
3. `backend/`로 가져온다.
4. 패키지명, 앱 이름, 환경 변수명을 NuguSauce 기준으로 바꾼다.
5. 배치 모듈은 초기에는 제외하거나 비활성화한다.

## Why drop batch first

- 현재 MVP에 정기 배치가 필수는 아니다.
- 랭킹 재계산, 신고 집계, 알림 발송이 생기면 그때 `batch`를 다시 붙이면 된다.
- 처음부터 `batch`까지 들고 오면 초기 설정과 CI 시간이 늘어난다.

## Backend slice after import

- `domain`: 엔티티, 리포지토리 인터페이스, 도메인 규칙
- `application`: 유스케이스, 인증, 트랜잭션, 외부 포트
- `api`: 컨트롤러, 시큐리티 설정, OpenAPI, DTO, 예외 매핑

## 8.1 Kakao auth decision for iOS

이전 `auth-oauth-addon` 템플릿의 Kakao OAuth2는 웹 리다이렉트 플로우에는 맞지만 iOS 네이티브 앱에는 맞지 않는다.

새 기준 브랜치인 `auth-kakao-sdk-oidc-app`는 iOS 앱이 Kakao SDK로 로그인한 뒤 backend가 OIDC ID token을 검증하고 자체 access/refresh token을 response body로 내려주는 방향으로 이미 정리되어 있다.

따라서 NuguSauce의 기준안은 아래처럼 잡는다.

- iOS 앱은 Kakao SDK로 로그인한다.
- backend는 웹형 `oauth2Login()`을 핵심 로그인 플로우로 쓰지 않는다.
- backend는 `POST /api/v1/auth/kakao/login` 네이티브 전용 social login endpoint를 사용한다.
- 기본안은 `OIDC id_token` 검증 방식이다.
- 이 브랜치를 기반으로 하면 access token 검증 fallback을 별도로 먼저 만들 필요는 없다.

이 결정은 OAuth2가 불가능해서가 아니라, iOS와 backend의 신뢰 경계에 OIDC가 더 맞고 템플릿 브랜치도 이미 그 방향으로 준비되어 있기 때문이다.

## 9. Harness Engineering Adoption

여기서 말하는 하네스 엔지니어링은 "기능을 구현하기 전에 반복 검증 가능한 틀을 먼저 만든다"는 뜻으로 잡는다.

핵심은 매번 사람 기억에 기대지 않고, 동일 입력에 대해 동일 결과를 재검증할 수 있는 환경을 만드는 것이다.

### Harness layers

`product harness`

- 유명 조합 20~30개를 시드 데이터로 고정
- 대표 사용자 시나리오를 명문화
- 예: "비로그인 사용자가 베스트 조합 상세를 본다"

`backend harness`

- OpenAPI 스냅샷
- 인증/인가 통합 테스트
- 레시피 등록, 평점 집계, 리뷰 작성 유스케이스 테스트
- Testcontainers 기반 DB/Redis 통합 테스트

`ios harness`

- 핵심 화면 상태 테스트
- ViewModel과 networking mock 기반 플로우 테스트
- XCUITest
- 예: 목록 조회, 상세 보기, 카카오 로그인 후 업로드, 리뷰 작성

`data harness`

- seed SQL 또는 JSON fixture
- 맛 태그, 재료 마스터, 유명 조합 샘플 고정
- 로컬/테스트 환경에서 항상 같은 데이터로 시작

`ops harness`

- `docker-compose`로 앱 + DB + Redis 기동
- `/health`, `/ready`, 로그인 콜백, 파일 업로드 같은 기본 smoke check
- 마이그레이션 적용 여부 검증

### How to work with it

기능 개발 순서는 아래처럼 고정한다.

1. 시나리오를 하네스 문서에 추가한다.
2. API 계약 또는 E2E 기대 결과를 먼저 쓴다.
3. 실패하는 테스트를 만든다.
4. 최소 구현으로 통과시킨다.
5. 로컬 smoke check와 배포 smoke check를 붙인다.

즉, "기능"이 아니라 "검증 가능 단위"를 먼저 만든 뒤 구현을 얹는다.

## 10. Suggested Milestones

### Milestone 0. Foundation

- 레포 초기화
- 루트 문서화
- `backend/ios/ops` 골격 생성
- 로컬 공통 개발 규칙 정리

### Milestone 1. Backend bootstrap

- 템플릿 이식
- 카카오 로그인 검증
- `auth-kakao-sdk-oidc-app` 기반 Kakao OIDC 로그인 검증
- Member, Recipe, Review 도메인 골격 추가
- OpenAPI와 기본 테스트 통과

### Milestone 2. iOS MVP

- 홈
- 인기 조합 목록
- 조합 상세
- 로그인
- 조합 등록 화면
- 리뷰 작성 화면

### Milestone 3. Harness completion

- 시드 데이터
- XCUITest 핵심 시나리오
- backend integration test
- OIDC login verification test
- docker-compose 개발 스택

### Milestone 4. Ops and release

- CI
- preview or dev deployment
- DB migration pipeline
- health check and alerting

## 11. Risks

- 브랜드/상표 표현: 공식 제휴가 아니라면 "공식 레시피"로 오해될 표현은 피해야 한다.
- 사용자 생성 콘텐츠: 신고, 숨김, 운영 로그가 빠지면 품질이 무너진다.
- 카카오 로그인: 로컬, 개발, 운영 redirect URI를 초기에 정리하지 않으면 반복적으로 막힌다.
- Kakao OIDC: nonce, audience, key rotation 검증을 빼먹으면 로그인 보안이 무너진다.
- 레시피 구조: 재료 단위를 문자열로 두면 나중에 검색/정렬/추천이 어려워진다.

## 12. First Execution Plan

가장 먼저 할 일은 아래다.

1. 루트 레포를 git으로 초기화한다.
2. `backend/ios/ops` 디렉터리와 각 README를 만든다.
3. 템플릿의 `auth-kakao-sdk-oidc-app`을 기준으로 `backend`를 가져온다.
4. `POST /api/v1/auth/kakao/login` 흐름을 NuguSauce 패키지와 설정으로 이식한다.
5. 수동 스키마 변경 항목을 NuguSauce migration 전략에 맞게 적용한다.
6. 배치 모듈 제외 여부를 확정하고 Gradle 설정을 정리한다.
7. `Recipe`, `RecipeIngredient`, `RecipeReview` 최소 도메인과 테스트를 만든다.
8. iOS 앱은 SwiftUI로 홈, 목록, 상세 와이어프레임을 만든다.
