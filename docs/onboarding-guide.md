# Claude Code Review 온보딩 가이드

> 각 레포에 Claude AI 기반 PR 자동 리뷰를 설정하는 가이드입니다.

## 개요

PR을 올리면 Claude가 자동으로 코드 리뷰를 해줍니다.
- **Auto-review**: PR 생성/업데이트 시 자동 리뷰
- **Interactive**: PR 코멘트에서 `@claude` 멘션으로 질문/대화
- 이전 리뷰 스레드는 PR 업데이트 시 자동 resolve

---

## 설정 방법 (5분)

### 1. Caller Workflow 추가

레포 루트에서:

```bash
curl -sL https://raw.githubusercontent.com/planfit/.github/v1/scripts/setup-claude-review.sh | bash
```

또는 수동으로:

1. 아래 내용을 `.github/workflows/claude-review.yml`에 저장

```yaml
name: Claude Code Review

on:
  pull_request:
    types: [opened, synchronize]
  issue_comment:
    types: [created]
  pull_request_review_comment:
    types: [created]

jobs:
  auto-review:
    if: github.event_name == 'pull_request'
    permissions:
      contents: read
      pull-requests: write
      issues: write
      id-token: write
    uses: planfit/.github/.github/workflows/claude-review.yml@v1
    with:
      trigger_action: ${{ github.event.action }}
      pr_number: ${{ github.event.pull_request.number }}
      pr_title: ${{ github.event.pull_request.title }}
      repo_name: ${{ github.event.repository.name }}
      repo_owner: ${{ github.repository_owner }}
    secrets: inherit

  interactive:
    if: >
      (github.event_name == 'issue_comment' || github.event_name == 'pull_request_review_comment') &&
      contains(github.event.comment.body, '@claude')
    runs-on: ubuntu-latest
    timeout-minutes: 30
    permissions:
      contents: read
      pull-requests: write
      issues: write
      id-token: write
    concurrency:
      group: claude-interactive-${{ github.event.issue.number || github.event.pull_request.number }}
      cancel-in-progress: false
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 1
      - uses: anthropics/claude-code-action@v1
        with:
          claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
          trigger_phrase: '@claude'
          claude_args: '--model claude-sonnet-4-6 --max-turns 15'
```

2. main/default 브랜치에 머지

### 2. (선택) 리뷰 커스터마이징

#### 설정 파일: `.claude-review.yml`

레포 루트에 생성. 없으면 기본값 사용.

```yaml
# .claude-review.yml
language: ko              # 리뷰 언어 (ko / en)
model: claude-sonnet-4-6  # Claude 모델
max_turns: 20             # 에이전트 최대 턴
diff_size_limit: 204800   # 최대 diff 크기 (bytes)

# 리뷰에서 제외할 파일 패턴 (grep -E)
# 기본 제외: .json, .svg, .png, .jpg, .gif, package-lock.json
exclude:
  - '^src/locales/'
  - '^migrations/'
```

#### 리뷰 규칙: `.claude/review-rules.md`

레포별 리뷰 규칙을 마크다운으로 작성. 없으면 CLAUDE.md 기반으로 리뷰.

```markdown
## 필수 검증 규칙
- any 타입 사용 금지
- console.* 직접 사용 금지

## 제외 규칙 (지적하지 말 것)
- import 순서 (자동 포매터가 처리)
- 서버 API 설계 변경 제안
```

> 템플릿: https://github.com/planfit/.github/blob/main/templates/review-rules-example.md

---

## 사용법

### Auto-review

PR을 올리면 자동 실행. 별도 작업 불필요.

- 리뷰 완료 시 인라인 코멘트 + summary comment 게시
- PR 업데이트(push) 시 이전 리뷰 자동 resolve 후 재리뷰

### Interactive

PR 코멘트에 `@claude`를 멘션하면 응답합니다.

```
@claude 이 함수의 시간 복잡도는?
@claude 이 변경이 기존 API에 영향을 주나요?
```

### 리뷰 건너뛰기

PR 제목에 아래 키워드를 포함하면 리뷰를 건너뜁니다:
- `WIP`
- `DRAFT`
- `DO NOT MERGE`
- `No Review`

---

## FAQ

**Q: Org Secret은 이미 등록되어 있나요?**
A: 네, `CLAUDE_CODE_OAUTH_TOKEN`이 org-level로 등록되어 있습니다. 레포별 추가 설정 불필요.

**Q: Claude GitHub App 설치가 필요한가요?**
A: Interactive (`@claude` 멘션) 기능을 사용하려면 레포에 https://github.com/apps/claude 가 설치되어 있어야 합니다.

**Q: 리뷰가 안 됩니다.**
A: 확인할 것:
1. Workflow가 default branch에 머지되었는지
2. PR 제목에 WIP/DRAFT 등이 포함되어 있지 않은지
3. 변경 파일이 제외 패턴에 해당하지 않는지 (json, 이미지 등)
4. Actions 탭에서 workflow 실행 로그 확인

**Q: 리뷰 언어를 변경하고 싶습니다.**
A: `.claude-review.yml`에 `language: en` 추가.

**Q: 특정 파일을 리뷰에서 제외하고 싶습니다.**
A: `.claude-review.yml`의 `exclude`에 패턴 추가. grep -E 정규식 사용.
