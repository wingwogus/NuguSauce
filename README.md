# 누구소스 (NuguSauce)

누구소스는 훠궈 소스 조합을 발견하고, 기록하고, 함께 평가하는 iOS 커뮤니티 앱입니다.

블로그나 숏폼 콘텐츠에 흩어진 소스 레시피를 재료와 비율 중심으로 정리해 보여주고, 사용자가 직접 만든 조합도 사진과 설명을 곁들여 공유할 수 있습니다. 다른 사용자의 평점과 리뷰를 참고해 취향에 맞는 조합을 찾고, 마음에 드는 레시피는 찜해 다시 확인할 수 있습니다.

## 주요 기능

- 인기 소스와 새로운 조합 탐색
- 맛 태그와 재료를 활용한 검색 및 필터
- 재료, 배합 비율, 맵기, 고소함, 팁을 포함한 레시피 상세 정보
- 사진을 포함한 나만의 소스 레시피 등록 및 수정
- 별점과 텍스트 리뷰 작성
- 마음에 드는 소스 찜하기
- 카카오 및 Apple 계정 로그인
- 부적절한 콘텐츠 신고와 운영자 숨김 처리
- 프로필 관리, 약관 확인, 회원 탈퇴

비로그인 사용자도 소스 목록과 상세 정보를 둘러볼 수 있습니다. 로그인하면 레시피 등록, 리뷰, 찜, 프로필 등 커뮤니티 기능을 사용할 수 있습니다.

## 기술 구성

| 영역 | 기술 |
| --- | --- |
| iOS | SwiftUI, Swift Concurrency, Kakao SDK, Sign in with Apple |
| Backend | Kotlin, Spring Boot, Spring Security, JPA |
| Data | PostgreSQL, Redis |
| API | REST, JWT 기반 세션, Kakao/Apple OIDC 검증 |
| Infrastructure | Docker, Kubernetes, Helm, Argo CD |
| Monitoring | Prometheus, Grafana, Loki, Promtail |

백엔드는 `api`, `application`, `domain` 모듈로 역할을 나눕니다. iOS 앱은 `App`, `Core`, `Features`, `Shared` 경계를 중심으로 화면, 인증, 네트워크, 공통 UI를 구성합니다.

## 저장소 구조

```text
.
├── backend/   # Kotlin/Spring Boot API
├── ios/       # SwiftUI iOS 앱과 테스트
├── ops/       # Helm, Argo CD, 배포 및 모니터링 설정
├── docs/      # API 계약과 운영 문서
└── .omx/      # 제품 요구사항과 테스트 계획
```

## 로컬 확인

백엔드 테스트는 다음 명령으로 실행합니다.

```bash
cd backend
./gradlew test
```

iOS 앱은 `ios/NuguSauce.xcodeproj`를 Xcode에서 열고 공유 스킴 `NuguSauce`로 실행합니다. 앱 실행에는 API 주소와 카카오 네이티브 앱 키 등 개발 환경 설정이 필요합니다.

Kubernetes 배포 리소스는 Helm으로 검증할 수 있습니다.

```bash
helm lint ops/helm/nugusauce-api
helm template nugusauce ops/helm/nugusauce-api --namespace nugusauce
```

## 문서

- [제품 요구사항](./.omx/plans/prd-nugusauce-v0.md)
- [테스트 명세](./.omx/plans/test-spec-nugusauce-v0.md)
- [API 계약](./docs/contracts/api.md)
- [시스템 구조](./ARCHITECTURE.md)
- [보안 정책](./SECURITY.md)
- [모니터링 운영 가이드](./docs/runbooks/monitoring.md)

누구소스는 실제 서비스 데이터와 API를 기준으로 동작하며, 앱에 임시 레시피나 데모용 사용자 데이터를 포함하지 않습니다.
