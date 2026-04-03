# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

Planfit organization의 공용 `.github` 레포. 핵심 기능은 **Claude Code Review reusable workflow** — 모든 Planfit 레포에서 PR 자동 리뷰를 제공하는 중앙 시스템.

## Architecture

```
Caller Workflow (각 레포)                Reusable Workflow (이 레포)
.github/workflows/claude-review.yml  →  .github/workflows/claude-review.yml
  ├── auto-review job ──────────────→    ├── Skip 조건 체크 (PR 제목)
  │                                      ├── Config 로드 (.claude-review.yml)
  │                                      ├── Diff 추출 + 파일 필터링
  │                                      ├── 리뷰 규칙 로드 (.claude/review-rules.md)
  │                                      ├── 이전 리뷰 스레드 resolve (synchronize 시)
  │                                      ├── Claude Review (primary token)
  │                                      ├── Claude Review (backup token fallback)
  │                                      └── Summary sticky comment
  └── interactive job (직접 실행)
      └── @claude 멘션 → anthropics/claude-code-action@v1
```

**Interactive job은 reusable workflow에 포함되지 않음** — `workflow_call` 이벤트에서 `github.event.comment.body`가 손실되기 때문에 각 레포의 caller에 직접 정의.

## Config System

각 레포에서 2개 파일로 리뷰를 커스터마이징:

| 파일 | 용도 | 필수 |
|------|------|------|
| `.claude-review.yml` (레포 루트) | 설정 (model, language, exclude 등) | 선택 |
| `.claude/review-rules.md` | 리뷰 규칙 (프롬프트에 주입) | 선택 |

- 설정 파일 없으면 기본값 사용
- 리뷰 규칙 없으면 CLAUDE.md 기반 폴백
- 하위 호환: `.github/claude-review-rules.md`도 지원 (`.claude/review-rules.md` 우선)

## Key Files

| 파일 | 역할 |
|------|------|
| `.github/workflows/claude-review.yml` | Reusable workflow 본체 (핵심) |
| `templates/caller-workflow.yml` | 각 레포에 복사할 caller 템플릿 |
| `templates/claude-review-config.yml` | `.claude-review.yml` 설정 템플릿 |
| `templates/review-rules-example.md` | `.claude/review-rules.md` 규칙 템플릿 |
| `scripts/setup-claude-review.sh` | 새 레포 온보딩 대화형 스크립트 |
| `examples/planfit-client-rn/` | planfit-client-rn 마이그레이션 참고용 |

## Design Decisions

- **Config 파일 기반 설정**: `.claude-review.yml` + `.claude/review-rules.md`로 레포별 커스터마이징 (`.coderabbit.yaml` 패턴)
- **Caller는 event context만 전달**: 설정은 reusable workflow가 checkout 후 config 파일에서 직접 읽음
- **Hybrid 프롬프트 방식**: `.claude/review-rules.md`가 있으면 사용, 없으면 CLAUDE.md 기반 폴백
- **Backup token fallback**: Primary `CLAUDE_CODE_OAUTH_TOKEN` 실패 시 `CLAUDE_CODE_OAUTH_TOKEN_BACKUP`으로 자동 재시도 (rate limit 대응)
- **태그 기반 버전 관리**: `@v1` 고정으로 중앙 수정 시 기존 레포에 breaking change 방지
- **`<!-- claude-review -->` 마커**: 리뷰 코멘트 식별 및 이전 리뷰 자동 resolve에 사용
- **`<!-- claude-code-review-summary -->` 마커**: Sticky summary comment 업데이트에 사용
- **YAML anchor 미지원**: GitHub Actions 제약으로 backup step에 프롬프트 중복 존재. 추후 composite action으로 개선 가능

## Editing Guidelines

- Reusable workflow 수정 시: primary/backup step의 프롬프트가 **동일해야 함** (YAML anchor 미지원으로 수동 동기화 필요)
- Summary comment의 마커 문자열 변경 시: Step 9/10 모두 업데이트 필요
- Config 파싱 로직 변경 시: Step 3 (Load config)의 shell 파싱 코드 수정
- `@v1` 태그 업데이트: `git tag -f v1 && git push origin v1 --force`

## Repo Visibility Constraint

이 레포는 **public**이어야 함 (Team 플랜). `private`이면 다른 레포에서 reusable workflow 호출 불가.
