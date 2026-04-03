# Claude Review Rules - planfit-client-rn

## 필수 검증 규칙 (반드시 지적할 것)

### 🔴 Path alias 위반 감지
- src 내부 파일에서 상대경로 import 사용 금지
- ❌ `from './파일명'` 또는 `from '../경로/파일명'`
- ✅ `from '@/경로/파일명'`
- **발견 시**: 🟡 Important 코멘트 작성

### 🟡 Named export 규칙
- default export 금지 (Redux slice reducers 제외)

### 🟡 타입 안전성
- `any` 타입 사용 금지

### 🟡 로깅 규칙
- `console.*` 대신 `logError`, `logWarning`, `LogInfoDevOnly` 사용

### 🟡 비즈니스 로직 일관성
- 같은 기능이 여러 화면/파일에 구현될 때 조건/가드 로직 누락 확인
- if/else 분기 중 한쪽에서만 처리되는 로직 확인

## 제외 규칙 (지적하지 말 것)

- ✅ A/B 테스트 실험 ID 버전 접미사 (예: `_3_159_1`, `_3_158_2`)
- ✅ import 순서 자동 정렬 오류 (prettier가 처리)
- ✅ 서버 API 설계 변경 제안 (단수→배열, ref→큐 등 데이터 구조 변경): 클라이언트만으로 서버 의도를 추측하지 마라
- ✅ 보호 메커니즘이 확인되는 race condition: 가드/플래그/동기적 접근으로 보호되면 지적하지 마라

## 자기 검증 (코멘트 작성 전 반드시 수행)

- "이 지적이 틀릴 수 있는 이유"를 먼저 생각하라
- 아키텍처/데이터 구조 변경 제안: 서버 API 설계를 모르므로 지적하지 마라
- 동시성/race condition: 기존 보호 메커니즘을 코드에서 확인하고, 구체적 우회 시나리오를 설명할 수 없으면 지적하지 마라
- 확신이 낮은 이슈는 제외하라

## 경로별 리뷰 포커스

| 경로 | 포커스 |
|------|--------|
| `src/**/*.{ts,tsx}` | CLAUDE.md 코드 컨벤션 준수, React/TS 베스트 프랙티스 |
| `src/amplitude/experiments/**` | A/B 테스트 네이밍 규칙 (위 제외 규칙 참조) |
| `src/store/modules/**` | Redux 상태 변경 시 하위 호환성 확인 |
| `src/controls/API/**` | `createApiRequest` 패턴 사용 여부 |
