# Kakao iOS Auth Decision v0

## 1. Question

NuguSauce의 iOS 앱과 백엔드 조합에서 Kakao `OAuth2`만으로 충분한지, 아니면 템플릿의 `auth-kakao-sdk-oidc-app` 브랜치 기반 `OIDC`로 가야 하는지 판단한다.

## 2. Short Answer

- iOS + backend 조합에서 Kakao `OAuth2`는 가능하다.
- 하지만 이전 `auth-oauth-addon`의 `Spring Security oauth2Login()` 방식은 웹 브라우저 리다이렉트 중심이라 iOS 네이티브 앱에는 잘 맞지 않는다.
- 새 `auth-kakao-sdk-oidc-app` 브랜치가 이미 Kakao SDK + OIDC 앱 로그인 구조를 담고 있으므로 이 브랜치를 기준으로 간다.
- 따라서 결론은 "`OAuth2`가 불가능해서 `OIDC`로 바꿔야 한다"가 아니라, "iOS 네이티브 앱에서는 `OIDC` 기반 서버 검증 방식이 더 적합하고 템플릿도 그 방향으로 준비되어 있다"이다.

## 3. What the previous template did

이전 `auth-oauth-addon` 템플릿은 웹 앱 기준 플로우에 가깝다.

- Spring Security가 `/oauth2/**`, `/login/oauth2/**` 리다이렉트 콜백을 직접 처리한다.
- 로그인 성공 시 서버가 앱 URL로 다시 redirect 하면서 access token을 query string으로 넘긴다.
- refresh token은 HTTP-only cookie로 저장한다.

이 방식은 브라우저 중심 서비스에는 자연스럽지만, iOS 앱에는 다음 문제가 있다.

- 앱이 서버 redirect와 cookie 저장소를 주도적으로 다루기 어렵다.
- access token을 URL query에 싣는 방식은 네이티브 앱 기준으로 깔끔하지 않다.
- Kakao SDK가 이미 iOS에서 로그인과 앱 복귀를 처리하는데, 서버 리다이렉트 플로우를 다시 중첩할 이유가 적다.

## 4. Option A: Keep OAuth2 for native login

### Flow

1. iOS 앱이 Kakao SDK로 로그인한다.
2. iOS 앱이 Kakao access token을 받는다.
3. 앱이 backend에 Kakao access token을 전달한다.
4. backend가 Kakao API로 token validity와 user info를 조회한다.
5. backend가 자체 JWT access/refresh token을 발급한다.

### Pros

- 구현이 단순하다.
- Kakao iOS SDK 기본 플로우와 잘 맞는다.
- OIDC 검증 로직 없이도 시작 가능하다.

### Cons

- backend가 로그인 검증마다 Kakao API 호출에 의존한다.
- 제3자 access token을 서버로 전달하는 구조라 경계가 다소 거칠다.
- `id_token`의 서명 검증 같은 표준 신원 검증 이점이 없다.

## 5. Option B: Switch to OIDC-native backend verification

### Flow

1. iOS 앱이 Kakao SDK로 로그인한다.
2. Kakao Login의 OpenID Connect를 활성화한다.
3. iOS 앱이 Kakao `id_token`과 필요 시 access token을 받는다.
4. 앱이 backend에 `id_token`과 `nonce`를 전달한다.
5. backend가 Kakao discovery/JWKS 기준으로 `id_token` 서명과 claim을 검증한다.
6. backend가 자체 JWT access/refresh token을 발급한다.

현재 `auth-kakao-sdk-oidc-app` 브랜치가 이 옵션을 구현한다.

### Pros

- 네이티브 앱 + 백엔드 구조에 더 표준적이다.
- backend가 Kakao user identity를 로컬 검증할 수 있다.
- 향후 Apple, Google 같은 다른 OIDC provider 추가 시 구조를 재사용하기 쉽다.

### Cons

- discovery, JWK cache, nonce 검증 등 구현 항목이 늘어난다.
- 최초 부트스트랩은 OAuth2 access-token 검증보다 조금 무겁다.

## 6. Decision

NuguSauce는 `auth-kakao-sdk-oidc-app` 브랜치의 `OIDC` 구현을 기본안으로 간다.

정확히는 아래처럼 잡는다.

- 카카오 로그인 자체는 iOS SDK를 사용한다.
- backend는 더 이상 `oauth2Login()` 리다이렉트 기반 로그인 진입점을 핵심 경로로 쓰지 않는다.
- backend는 `POST /api/v1/auth/kakao/login` 네이티브 전용 엔드포인트를 제공한다.
- 요청 본문으로 `idToken`, `nonce`, 필요 시 `deviceInfo` 정도를 받는다.
- backend는 Kakao `iss`, `aud`, `exp`, `nonce`, 서명을 검증한 뒤 서비스 회원을 생성 또는 로그인 처리한다.
- 이후에는 서비스 자체 JWT access/refresh token만 사용한다.

즉, 외부 provider 토큰은 "로그인 증명"으로만 쓰고, 서비스 세션은 자체 토큰으로 분리한다.

## 7. Fallback stance

이제 OIDC 브랜치가 있으므로 OAuth2 access token 검증 fallback을 1차 구현으로 둘 필요는 낮다.

fallback이 필요한 경우는 아래로 제한한다.

1. Kakao OIDC 설정 또는 iOS SDK nonce 전달이 실제 기기에서 막힌다.
2. QA 일정상 앱 로그인 unblock이 먼저 필요하다.
3. 그래도 API shape는 `POST /api/v1/auth/kakao/login`로 유지한다.

이 경우에도 `oauth2Login()` 웹 리다이렉트 플로우를 새 기준으로 삼지는 않는다.

## 8. Backend import list

### Keep

- 템플릿의 멀티모듈 구조
- 자체 JWT 발급 로직
- Member 저장 구조
- 보안 필터 체인 기반 인증 보호 구조

### Already replaced in `auth-kakao-sdk-oidc-app`

- `oauth2Login()` 성공 핸들러 중심 로그인 완료 방식
- redirect 기반 Kakao callback 완료 방식
- refresh token cookie 중심 세션 전달 방식

### Bring into NuguSauce

- `POST /api/v1/auth/kakao/login`
- Kakao ID token verifier
- JWK fetch/cache
- nonce 검증 저장소 또는 짧은 수명 검증 전략
- response body 기반 native app용 token response

`auth-kakao-sdk-oidc-app` 브랜치에는 endpoint, request/response DTO, verifier, JWK discovery, Redis nonce replay 방지, service token response가 이미 들어가 있다.

## 9. iOS change list

- Kakao iOS SDK 추가
- KakaoTalk/Account login 구현
- nonce 생성 및 전달
- backend token exchange API 호출
- 서비스 JWT/refresh token을 Keychain에 저장

## 10. Verification

최소 검증 항목은 아래다.

1. 유효한 Kakao `id_token`으로 로그인 성공
2. 잘못된 `nonce`로 로그인 실패
3. 다른 audience의 `id_token` 거부
4. 만료된 `id_token` 거부
5. 기존 회원 재로그인과 신규 회원 가입 흐름 분리 검증
