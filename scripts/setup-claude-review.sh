#!/bin/bash
#
# Claude Code Review 설정 헬퍼
#
# 사용법:
#   curl -sL https://raw.githubusercontent.com/planfit/.github/v1/scripts/setup-claude-review.sh | bash
#
# 또는 레포를 clone한 경우:
#   bash path/to/setup-claude-review.sh
#
# 이 스크립트는 현재 디렉토리에 Claude Code Review caller workflow를 생성합니다.
#

set -e

TEMPLATE_BASE="https://raw.githubusercontent.com/planfit/.github/v1/templates"
WORKFLOW_DIR=".github/workflows"
WORKFLOW_FILE="$WORKFLOW_DIR/claude-review.yml"
CONFIG_FILE=".claude-review.yml"
RULES_DIR=".claude"
RULES_FILE="$RULES_DIR/review-rules.md"

echo ""
echo "🤖 Claude Code Review 설정"
echo "=========================="
echo ""

# Git 레포 확인
if [ ! -d ".git" ] && [ ! -f ".git" ]; then
  echo "❌ 현재 디렉토리가 Git 레포가 아닙니다."
  echo "   레포 루트에서 실행해주세요."
  exit 1
fi

# 기존 workflow 확인
if [ -f "$WORKFLOW_FILE" ]; then
  echo "⚠️  이미 $WORKFLOW_FILE 이 존재합니다."
  read -p "덮어쓰시겠습니까? (y/N): " OVERWRITE
  if [ "$OVERWRITE" != "y" ] && [ "$OVERWRITE" != "Y" ]; then
    echo "취소되었습니다."
    exit 0
  fi
fi

# 1. Workflow 디렉토리 생성
mkdir -p "$WORKFLOW_DIR"

# 2. Caller workflow 다운로드
echo "📥 Caller workflow 생성..."
if command -v curl &>/dev/null; then
  curl -sL "$TEMPLATE_BASE/caller-workflow.yml" -o "$WORKFLOW_FILE"
elif command -v wget &>/dev/null; then
  wget -qO "$WORKFLOW_FILE" "$TEMPLATE_BASE/caller-workflow.yml"
else
  echo "❌ curl 또는 wget이 필요합니다."
  exit 1
fi
echo "   ✅ $WORKFLOW_FILE 생성 완료"

# 3. 설정 파일 생성 (선택)
echo ""
read -p "설정 파일(.claude-review.yml)을 생성할까요? (y/N): " CREATE_CONFIG
if [ "$CREATE_CONFIG" = "y" ] || [ "$CREATE_CONFIG" = "Y" ]; then
  echo "📥 설정 파일 생성..."
  if command -v curl &>/dev/null; then
    curl -sL "$TEMPLATE_BASE/claude-review-config.yml" -o "$CONFIG_FILE"
  else
    wget -qO "$CONFIG_FILE" "$TEMPLATE_BASE/claude-review-config.yml"
  fi
  echo "   ✅ $CONFIG_FILE 생성 완료"
  echo "   ✏️  레포에 맞게 수정하세요."
fi

# 4. 리뷰 규칙 파일 생성 (선택)
echo ""
read -p "리뷰 규칙 파일(.claude/review-rules.md)을 생성할까요? (y/N): " CREATE_RULES
if [ "$CREATE_RULES" = "y" ] || [ "$CREATE_RULES" = "Y" ]; then
  mkdir -p "$RULES_DIR"
  echo "📥 리뷰 규칙 템플릿 생성..."
  if command -v curl &>/dev/null; then
    curl -sL "$TEMPLATE_BASE/review-rules-example.md" -o "$RULES_FILE"
  else
    wget -qO "$RULES_FILE" "$TEMPLATE_BASE/review-rules-example.md"
  fi
  echo "   ✅ $RULES_FILE 생성 완료"
  echo "   ✏️  레포에 맞게 수정하세요."
fi

echo ""
echo "==============================="
echo "✅ Claude Code Review 설정 완료!"
echo "==============================="
echo ""
echo "📋 다음 단계:"
echo "  1. $WORKFLOW_FILE 확인"
if [ "$CREATE_CONFIG" = "y" ] || [ "$CREATE_CONFIG" = "Y" ]; then
  echo "  2. $CONFIG_FILE 수정 (모델, 언어, 제외 패턴 등)"
fi
if [ "$CREATE_RULES" = "y" ] || [ "$CREATE_RULES" = "Y" ]; then
  echo "  3. $RULES_FILE 수정 (리뷰 규칙)"
fi
echo "  4. Org secret 확인: CLAUDE_CODE_OAUTH_TOKEN"
echo "     (GitHub → Org Settings → Secrets → Actions)"
echo "  5. GitHub App 설치 확인: https://github.com/apps/claude"
echo "  6. 커밋 & 푸시 (main/default branch에 merge)"
echo ""
echo "📖 자세한 문서: https://github.com/planfit/.github#readme"
echo ""
