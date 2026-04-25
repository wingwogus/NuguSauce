# NuguSauce Test Spec v0

## 1. Goal

NuguSauce는 소셜 커뮤니티 성격과 인증 흐름이 함께 있는 앱이다.

따라서 검증 기준은 단순 unit test가 아니라, 아래 네 가지가 동시에 맞아야 한다.

- 인증이 실제로 동작한다.
- 레시피와 리뷰가 의도한 규칙으로 저장된다.
- 대표 사용자 플로우가 iOS 앱에서 끝까지 통과한다.
- 로컬과 배포 환경이 같은 기본 전제를 공유한다.

## 2. Canonical Fixtures

아래 fixture는 초기에 반드시 고정한다.

- `users`: 일반 사용자, 리뷰 많은 사용자, 신고 누적 사용자
- `recipes_curated`: 유명 조합 20~30개
- `recipes_user_generated`: 자작 조합 10개
- `ingredients_master`: 마늘, 고수, 참기름, 땅콩소스, 다진 고추 등
- `reviews`: 평점 분포가 섞인 샘플 데이터

목표는 테스트마다 같은 데이터 문맥을 재사용하는 것이다.

## 3. Backend Harness

### Unit tests

- 평점 평균 계산
- 리뷰 수 집계
- 검색 필터 조합
- 레시피 등록 검증
- 신고 임계치 판정

### Application tests

- 로그인 사용자가 레시피를 등록한다
- 중복 평점 정책을 적용한다
- 리뷰 작성 시 평점 집계를 갱신한다
- 숨김 처리된 레시피는 공개 목록에서 제외된다

### Integration tests

- Kakao OAuth2 로그인 성공/실패 흐름
- Kakao OIDC `id_token` 검증 성공/실패 흐름
- `POST /api/v1/auth/kakao/login` token exchange 성공/실패 흐름
- JWT 발급 이후 인증 보호 엔드포인트 접근
- Postgres 저장
- Redis 사용 시 세션 또는 캐시 동작

### Contract tests

- OpenAPI 문서 스냅샷
- 주요 응답 DTO JSON 스냅샷
- validation error shape 고정

## 4. iOS Harness

### Unit and state checks

- 레시피 카드 ViewModel 상태 변화
- 별점 입력 상태 변화
- 필터 조합 변경
- 등록 폼 validation
- 인증 세션 저장과 복원
- Kakao 로그인 결과 수신 후 backend token exchange 상태 전이

### XCUITest E2E

핵심 시나리오는 아래 네 개를 첫 배치로 고정한다.

1. 비로그인 사용자가 홈에서 인기 조합 목록과 상세를 본다.
2. 카카오 로그인 사용자가 새 조합을 등록한다.
3. 로그인 사용자가 별점과 리뷰를 남긴다.
4. 숨김 처리된 조합이 앱의 공개 목록에서 보이지 않는다.

### Visual QA

- 홈
- 목록
- 상세
- 등록 화면

위 네 화면은 레이아웃이 안정화되면 스냅샷 기준을 잡는다.

## 5. Ops Harness

### Local stack

- backend
- postgres
- redis

`docker-compose up` 기준으로 backend, postgres, redis가 함께 기동되어야 하고, iOS 앱은 simulator에서 이 로컬 스택을 대상으로 붙을 수 있어야 한다.

### Smoke checks

- backend `/actuator/health`
- 로그인 시작 엔드포인트
- 레시피 목록 API
- iOS 앱 기본 launch smoke

### Release checks

- migration 성공
- environment variable 누락 없음
- health endpoint 정상
- 주요 API 응답 정상
- iOS 앱 cold launch 및 핵심 화면 진입 가능

## 6. CI Gates

PR 기준 최소 게이트는 아래다.

1. backend unit and integration tests
2. iOS unit tests and UI tests
3. OpenAPI drift check
4. XCUITest smoke scenario
5. OIDC token verification regression test

## 7. Definition Of Done

기능은 아래를 모두 만족해야 끝난 것으로 본다.

- 요구사항 문장 하나 이상이 테스트로 고정되었다.
- backend 또는 iOS 중 영향받는 면이 자동 검증된다.
- fixture가 새 기능 문맥을 반영한다.
- 로컬 smoke check가 통과한다.
- 문서 또는 API 계약이 현재 동작과 맞다.

## 8. First Harness Backlog

초기 구현 전에 먼저 만들 항목은 아래다.

1. 유명 조합 fixture 초안
2. Kakao OIDC login integration test baseline
3. recipe create/review create application test
4. recipe list/detail XCUITest smoke test
5. docker-compose local stack
