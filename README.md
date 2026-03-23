# planfit/.github

Planfit organization 공용 설정 및 reusable workflows.

## Claude Code Review

AI 기반 PR 자동 리뷰 시스템. 모든 레포에서 사용 가능합니다.

### 빠른 시작

레포 루트에서 실행:

```bash
curl -sL https://raw.githubusercontent.com/planfit/.github/v1/scripts/setup-claude-review.sh | bash
```

또는 수동 설정:

1. `templates/caller-workflow.yml`을 레포의 `.github/workflows/claude-review.yml`로 복사
2. (선택) `templates/claude-review-rules-example.md`를 `.github/claude-review-rules.md`로 복사 후 수정
3. 커밋 & 푸시

### 사전 요구사항

| 항목 | 설정 위치 |
|------|----------|
| **Org Secret**: `CLAUDE_CODE_OAUTH_TOKEN` | GitHub → Org Settings → Secrets → Actions |
| **Org Secret**: `CLAUDE_CODE_OAUTH_TOKEN_BACKUP` (선택) | 동일 |
| **GitHub App**: Claude | https://github.com/apps/claude |

### 기능

| 기능 | 설명 |
|------|------|
| **Auto-review** | PR 열릴 때/업데이트 시 자동 코드 리뷰 |
| **Interactive** | PR 코멘트에서 `@claude` 멘션으로 대화 |
| **Backup fallback** | Primary 토큰 실패 시 backup 자동 전환 |
| **Thread resolve** | PR 업데이트 시 이전 리뷰 스레드 자동 resolve |
| **Sticky comment** | 리뷰 결과 요약 코멘트 (업데이트 시 갱신) |

### 커스터마이징

#### Caller Workflow Inputs

| Input | 기본값 | 설명 |
|-------|--------|------|
| `additional_exclude` | `''` | 추가 파일 제외 패턴 (grep -E) |
| `model` | `claude-sonnet-4-6` | Claude 모델 |
| `max_turns` | `20` | 최대 에이전트 턴 수 |
| `review_language` | `ko` | 리뷰 언어 (`ko` 또는 `en`) |
| `diff_size_limit` | `204800` | 최대 diff 크기 (bytes) |

#### 레포별 리뷰 규칙

`.github/claude-review-rules.md` 파일을 레포에 생성하면, Claude가 해당 규칙을 우선 적용합니다.
파일이 없으면 CLAUDE.md 기반으로 리뷰합니다.

예시: `templates/claude-review-rules-example.md`

### 자동 스킵 조건

다음 경우 리뷰를 건너뜁니다:

- PR 제목에 `WIP`, `DRAFT`, `DO NOT MERGE`, `No Review` 포함
- 변경 파일이 모두 제외 패턴에 해당 (번역, 이미지, 스크립트 등)

### 기본 제외 파일

| 패턴 | 설명 |
|------|------|
| `*.json` | JSON 파일 |
| `*.svg/png/jpg/gif` | 이미지 |
| `package-lock.json` | 자동 생성 |

`additional_exclude`로 레포별 추가 제외 가능:
```yaml
additional_exclude: '^src/locales/|^migrations/|^docs/'
```

### 버전 관리

```yaml
# 안정 버전 (권장)
uses: planfit/.github/.github/workflows/claude-review.yml@v1

# 최신 (주의: breaking change 가능)
uses: planfit/.github/.github/workflows/claude-review.yml@main
```

### 트러블슈팅

| 문제 | 원인 | 해결 |
|------|------|------|
| Workflow 트리거 안 됨 | default branch에 workflow 없음 | main에 merge 필요 |
| 리뷰 실패 (rate limit) | 토큰 사용량 초과 | backup 토큰 설정 또는 대기 |
| Interactive 응답 없음 | Claude App 미설치 | https://github.com/apps/claude 확인 |
| Permission denied | Workflow permissions 부족 | caller에 permissions 블록 확인 |

### 아키텍처

```
PR 생성/업데이트
  │
  ├── Caller Workflow (각 레포)
  │   ├── auto-review job ──→ Reusable Workflow (planfit/.github)
  │   │                        ├── Diff 추출 + 필터링
  │   │                        ├── 리뷰 규칙 로드
  │   │                        ├── 이전 리뷰 resolve
  │   │                        ├── Claude Review (primary)
  │   │                        ├── Claude Review (backup fallback)
  │   │                        └── Summary comment
  │   │
  │   └── interactive job ──→ claude-code-action (직접 실행)
  │                            └── @claude 멘션 대응
  │
  └── Secrets (Org-level)
      ├── CLAUDE_CODE_OAUTH_TOKEN
      └── CLAUDE_CODE_OAUTH_TOKEN_BACKUP (선택)
```
