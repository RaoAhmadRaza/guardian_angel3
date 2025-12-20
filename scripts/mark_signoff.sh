#!/usr/bin/env bash
# scripts/mark_signoff.sh
#
# Release Sign-off CLI
# Creates a Git tag and pushes release when sign-off is approved
#
# Prerequisites:
#   - release-checklist.json exists (run generate_release_checklist.dart)
#   - All automated checks have passed
#   - Manual checks have been completed
#
# Usage:
#   bash scripts/mark_signoff.sh

set -e

REPORT="release-checklist.json"
BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "═══════════════════════════════════════════════════════════"
echo "  Guardian Angel FYP - Release Sign-off"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${RED}❌ Error: jq is not installed${NC}"
    echo "   Install: brew install jq (macOS) or apt-get install jq (Linux)"
    exit 1
fi

# Check if release-checklist.json exists
if [ ! -f "$REPORT" ]; then
    echo -e "${RED}❌ Error: $REPORT not found${NC}"
    echo ""
    echo "Please run the following commands first:"
    echo "  1. dart run tool/run_all_tests.dart"
    echo "  2. dart run tool/acceptance_runner.dart"
    echo "  3. dart run scripts/generate_release_checklist.dart"
    exit 2
fi

echo -e "${BOLD}📋 Release Checklist Review${NC}"
echo "─────────────────────────────────────────────────────────────"
echo ""

# Display checklist
jq '.' "$REPORT"

echo ""
echo "─────────────────────────────────────────────────────────────"
echo ""

# Check if release is ready
RELEASE_READY=$(jq -r '.release_ready' "$REPORT")
if [ "$RELEASE_READY" != "true" ]; then
    echo -e "${RED}❌ Release is NOT ready${NC}"
    echo "   Fix failing automated checks before proceeding"
    exit 3
fi

echo -e "${GREEN}✅ All automated checks passed${NC}"
echo ""

# Verify manual checks
echo -e "${BOLD}Manual checks verification:${NC}"
echo ""
echo "Please confirm you have completed:"
echo "  □ Metrics dashboard review"
echo "  □ Security review"
echo "  □ Performance profiling (if required)"
echo "  □ Documentation review"
echo ""

# Prompt for sign-off
echo "─────────────────────────────────────────────────────────────"
echo ""
echo -e "${YELLOW}⚠️  WARNING: This will create and push a release tag${NC}"
echo ""
read -p "Type SIGNOFF to approve release (or anything else to cancel): " APPROVE

if [ "$APPROVE" != "SIGNOFF" ]; then
    echo ""
    echo "❌ Sign-off aborted"
    exit 1
fi

echo ""
echo "─────────────────────────────────────────────────────────────"
echo ""

# Generate tag name
TAG="release-$(date +%Y%m%d-%H%M%S)"
echo "📦 Creating release tag: $TAG"

# Get current branch
BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "📍 Current branch: $BRANCH"

# Create annotated tag
COMMIT_HASH=$(git rev-parse --short HEAD)
echo "🔖 Commit: $COMMIT_HASH"

git tag -a "$TAG" -m "Release sign-off

Automated checks: PASSED
Manual checks: COMPLETED
Sign-off date: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
Signed-off by: $(git config user.name) <$(git config user.email)>
Branch: $BRANCH
Commit: $COMMIT_HASH

This release has been validated through:
- Unit tests
- Integration tests
- E2E acceptance scenarios
- Manual verification
- Security review

See release-checklist.json for details."

echo ""
echo -e "${GREEN}✅ Tag created: $TAG${NC}"
echo ""

# Push tag
echo "🚀 Pushing tag to remote..."
git push origin "$TAG"

echo ""
echo -e "${GREEN}✅ Release tag pushed successfully${NC}"
echo ""
echo "─────────────────────────────────────────────────────────────"
echo ""
echo "📦 Release: $TAG"
echo "🔗 View on GitHub:"
echo "   https://github.com/$(git remote get-url origin | sed 's/.*github.com[:/]\(.*\)\.git/\1/')/releases/tag/$TAG"
echo ""
echo "Next steps:"
echo "  1. Create GitHub release from tag"
echo "  2. Attach release notes"
echo "  3. Notify team"
echo ""
echo "═══════════════════════════════════════════════════════════"
