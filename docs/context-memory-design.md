# Claude Review — 지속 컨텍스트(Persistent Context) 설계

> 목적: stateless한 리뷰 에이전트에 **PR 내 증분 기억**과 **PR 간 학습 기억**을 부여한다.
> 작성: 2026-06-10. 상태: **설계(미구현)**. 구현 전 canary 필수.

## 1. 문제 정의

claude-code-action의 매 실행은 **완전히 새 세션**이다. run 간 메모리·`--resume`이 없다.
따라서 컨텍스트는 **PR 스레드 + 레포 파일**로만 영속화 가능하다 (업계 공통: "Claude has no memory. Your log does").

끊기는 지점 3개:

| 갭 | 현상 | 현재 동작 |
|---|---|---|
| **G1** PR 내 시간축 | push 2차 리뷰가 1차를 모름 | Step6가 직전 스레드를 **읽지 않고 전부 resolve** → 매번 from-scratch |
| **G2** PR 간 longitudinal | 같은 false-positive 반복 (예: AB ID `_3_158_2` 숫자) | `review-rules.md` 수동 편집만, 학습 루프 없음 |
| **G3** interactive ↔ auto | `@claude` 답변이 auto-review를 모름 | 완전 분리 |

## 2. Best-practice 근거 (조사 결과)

- **CodeRabbit "Learnings"**: 자연어 선호를 org DB에 적립. 채팅에서 생성, "Learnings Added" 섹션으로 **명시 공개**. 대시보드에 usage/never-used/last-used 추적. 증분 리뷰("resolved 코멘트 재발 안 함").
- **Greptile "Memory & Learning"**: 팀 코멘트·리액션·답글·머지를 읽어 학습, 2~3주 뒤 "신경 안 쓰는 것"은 **자동 침묵(decay)**. `.greptile/rules` + CLAUDE.md 자동 인덱싱.
- **공식 Claude review**: 영속 채널 = 레포 파일(REVIEW.md "Always check / Skip / Style"). push 리뷰가 수정된 스레드 auto-resolve, 미수정은 유지. 👍👎는 Anthropic 자체 튜닝용(우리 레포엔 미반영).

**추출 원칙 5:** ① 증분(델타+carry-forward) ② 자연어 학습(regex 아님) ③ 명시/투명 ④ decay/pruning ⑤ **사람 큐레이션 게이트**(self-hosted 필수).

## 3. 아키텍처: 3-layer 영속화

에이전트가 stateless이므로 컨텍스트를 3개 레이어로 외부화한다.

```
L1 정적 규칙   .claude/review-rules.md      (존재)  — Always/Skip/Style
L2 학습 메모리  .claude/review-memory.md     (신규)  — 큐레이션된 자연어 학습
L3 PR 내 상태  PR 리뷰 스레드 + 답글          (존재 채널) — 증분 리뷰
```

- **L1·L2**: 레포 파일. org 워크플로 Step5에서 `/tmp/`로 로드 → 프롬프트 주입.
- **L3**: org 워크플로 Step6를 "blind resolve" → "capture → carry-forward → resolve"로 교체.
- **opt-in 안전성**: `review-memory.md`가 없으면 동작 변화 0 (기존 레포 무영향).

## 4. `review-memory.md` 스키마

MEMORY.md 패턴(인덱스+엔트리) + CodeRabbit Learnings를 마크다운으로. 사람이 diff·편집 가능.

```markdown
# Claude Review — 학습 메모리

> 큐레이션된 리뷰 학습. **봇이 직접 커밋하지 않는다** — 큐레이션 PR로만 추가/수정.
> 형식: RM-NNN 엔트리. scope는 glob. uses/last_used는 decay 판단용(주기 job이 갱신).

### RM-001 · AB 실험 ID 버전 접미사 숫자
- rule: 실험 ID의 `_3_158_2` 같은 **버전 접미사 숫자**는 "숫자 포함" 위반으로 지적하지 마라
- scope: src/amplitude/experiments/**
- origin: PR #10231 · @jun dismiss · 2026-06-10
- uses: 0 · last_used: —

### RM-002 · mp4 require() 패턴 정당
- rule: `require('@assets/mp4/...')` → `resolveMp4Asset()` 변경 제안 금지 (네이티브 link 미사용)
- scope: **/*.tsx
- origin: CLAUDE.md 🔴 규칙 · seed
- uses: 0 · last_used: —
```

- **ID(RM-NNN)**: 사용량 추적·decay 참조 키.
- **seed**: client-rn의 이미 아는 false-positive 2~3건으로 초기 적립(즉시 가치).

## 5. 변경 set

### 5-A. org 레포(planfit-dot-github) — `@v1` 영향, canary 필수

1. **Step5 확장**: `review-rules.md`에 더해 `.claude/review-memory.md`도 `/tmp/review-memory.md`로 복사, `has_memory` 출력.
2. **Step6 교체** ("Resolve previous" → "Capture + carry-forward + resolve"):
   - GraphQL 쿼리 확장: 스레드별 `path`, `line`, `isResolved`, **전체 comments(개발자 답글 포함)**, 리액션 수.
   - `<!-- claude-review -->` 마커 스레드를 `/tmp/prior-review.md`로 덤프 (지적 본문 + 개발자 답글 + resolved 여부).
   - 덤프 **후** 기존대로 resolve (스레드 누적 방지). synchronize에서만.
3. **프롬프트(Step7 & 8 동시)**: 입력 파일에 memory·prior-review 추가 + 두 섹션 규칙 주입
   - "이전 리뷰 컨텍스트": (a) 이미 반영/수정된 건 재지적 금지 (b) 개발자가 반박/의도라 한 건 재지적 금지 (c) 미해결 Critical만 유지.
   - "학습 메모리": scope 매칭되는 RM 항목을 **강한 제약**으로 준수.
   - ⚠️ primary/backup **양쪽 동일 수정** (YAML anchor 미지원).
   - 크기 가드: prior-review·memory도 `head -c`로 상한.

### 5-B. 학습 루프 (메모리 쓰기) — **구현됨**

`comment.body`가 필요하므로 **org reusable 밖**(interactive와 동일 이유) → 신규 reusable `claude-learn.yml` + caller `learn` job.

- **트리거 (v1: 명시 opt-in)**: 개발자가 `@claude learn: <자연어>` 또는 Claude 스레드에 `@claude dismiss <이유>` → caller의 `learn` job이 `claude-learn.yml@v1` 호출.
- **동작**: 코멘트를 한 개 RM 엔트리로 distill → **`.claude/review-memory.md`에 추가하는 큐레이션 PR 자동 생성**(자동 머지 ❌) → 사람이 머지하면 active. 원본 PR에 큐레이션 PR 링크 코멘트.
- **이유**: 개발자도 틀릴 수 있음 → 사람 게이트. "LLM 판단, regex 아님" 원칙.
- **caller 배선**: `interactive` job `if`에서 `@claude learn`/`@claude dismiss` 제외(중복 발화 방지). 템플릿 `templates/caller-workflow.yml` 반영.
- **구현 파일**: `.github/workflows/claude-learn.yml`(reusable), `templates/caller-workflow.yml`(learn job).
- **canary 검증 포인트**: claude-code-action의 github MCP 도구명(`create_branch`/`create_or_update_file`/`create_pull_request`/`add_issue_comment`) 실제 가용 여부 — 실패 시 도구명 조정.
- 자동 dismissal 감지(답글/👎 스캔)는 오탐 위험이라 **v2로 보류**(현재는 명시 `@claude learn`/`dismiss`만).

### 5-C. decay/pruning (v2, 선택)

- cron 워크플로: `review-memory.md`의 `uses:`/`last_used` 스캔 → N일·N리뷰 미사용 RM을 **pruning PR**로 제안.
- `uses:` 갱신: 리뷰가 적용한 RM-ID를 emit → 후속 step이 카운터 커밋. (v1은 생략, created-date+수동 검토 우선)
- 팀 기존 culling 정책("3회 연속 NO → 삭제")과 동형.

## 6. 배포·롤백 (blast radius 관리)

`@v1`은 이동 태그 → 강제 푸시 시 **전 레포 동시**.

### 🔴 핵심 제약 (canary 시 발견, 2026-06-10)

claude-code-action의 GitHub App은 **PR 브랜치의 워크플로우 파일이 default 브랜치와 동일해야** 토큰을 발급한다(보안).

- **caller 워크플로우를 수정한 PR에서는 Claude 리뷰가 안 돈다** (401 "Workflow validation failed" — 정상 동작, 무시 대상).
- **결론: "feature PR에서 caller를 SHA 핀해 canary"는 불가능.** caller ref 변경 = 워크플로우 변경 = 토큰 거부.
- 검증 대상은 **client 레포의 caller 파일**이 default와 일치하는지 뿐 — reusable(`claude-review.yml`) 내용 변경은 무관. caller가 `@v1` 그대로면 reusable이 바뀌어도 통과.

### 올바른 canary (scoped, 1개 레포만)

1. org PR 머지 → `planfit/.github` main 반영(아직 `@v1` 안 옮김).
2. **client-rn caller를 `@feat/persistent-context`(또는 SHA)로 핀한 채 dev(default)에 머지** → client-rn default-branch caller만 신규 reusable을 가리킴. 타 레포 `@v1` 유지 → 무영향.
3. client-rn **실제 PR**(caller 미수정)에서 검증 — 워크플로우가 default와 일치하므로 토큰 발급됨. L2 주입/L3 carry-forward/learn 관찰.
4. 통과 시 `git tag -f v1 && git push origin v1 --force` → 전 레포 적용. client-rn caller `@v1` 복귀.
5. 롤백: 직전 SHA로 `v1` 재태깅.

**canary 검증됨(PR #10343)**: caller `@feat` resolve + reusable 끝까지 실행 + `has_memory=true`(L2) + Step6 opened skip(L3 게이팅). **미검증**(토큰 거부로 모델 미실행): 실제 리뷰 출력 → scoped canary 필요.

**안전순서**: L2(opt-in, 무위험) → scoped canary로 L3·learn 검증 → `@v1` 이동.

## 7. 리스크

| 리스크 | 완화 |
|---|---|
| `@v1` 전 레포 동시 영향 | canary + 단계적 + opt-in 파일 |
| 프롬프트 2곳 drift | 변경 체크리스트, 추후 composite action |
| 메모리 오염(개발자 오판) | 큐레이션 PR 게이트 |
| 프롬프트 비대 | prior-review·memory `head -c` 상한 |
| 메모리 무한 증식 | decay/pruning(v2) |

## 8. 범위 밖 (v2)

- **decay/pruning 자동화**(5-C): `uses`/`last_used` 스캔 → pruning PR. 사용량 카운터 write-back 포함.
- **G3**: interactive job에 rules/memory 로드 추가.
- **자동 dismissal 감지**: 답글/👎 스캔으로 `@claude learn` 없이도 학습 후보 추출.
- composite action 리팩터(primary/backup 프롬프트 단일화) — 별도 작업.

## 9. 구현 현황 (2026-06-10)

| 항목 | 상태 | 위치 |
|---|---|---|
| L1 정적 규칙 | 기존 | `.claude/review-rules.md` |
| L2 메모리 로드 | ✅ | `claude-review.yml` Step5 |
| L2 seed | ✅ | (client-rn) `.claude/review-memory.md` |
| L3 carry-forward | ✅ | `claude-review.yml` Step6 |
| 프롬프트 주입(primary+backup) | ✅ | `claude-review.yml` Step7·8 |
| 학습 루프(5-B) | ✅ | `claude-learn.yml` + caller `learn` job |
| 가이드 스킬 | ✅ | `planfit:review-memory` (plugin PR #33) |
| canary 배포 | ⏳ | client-rn caller SHA 핀 → `@v1` 이동 |
| decay·G3·자동감지 | ⏳ v2 | — |
