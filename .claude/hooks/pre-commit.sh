#!/bin/bash
# Claude Code pre-commit hook
# Runs SwiftLint and SwiftFormat on staged Swift files

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "🔍 Running pre-commit checks..."

STAGED_SWIFT_FILES=$(git diff --cached --name-only --diff-filter=d | grep '\.swift$' || true)

# Skip excluded directories.
STAGED_SWIFT_FILES=$(echo "$STAGED_SWIFT_FILES" | grep -v -E '^\.derivedData/|^\.build/|/\.build/|^Devvy\.xcodeproj/' || true)

if [ -z "$STAGED_SWIFT_FILES" ]; then
    echo -e "${GREEN}✓ No Swift files staged, skipping checks${NC}"
    exit 0
fi

echo "📝 Checking ${STAGED_SWIFT_FILES}"

if command -v swiftformat &> /dev/null; then
    echo "🎨 Running SwiftFormat..."
    while IFS= read -r file; do
        if [ -f "$file" ]; then
            swiftformat "$file"
        fi
    done <<< "$STAGED_SWIFT_FILES"

    while IFS= read -r file; do
        if [ -f "$file" ]; then
            git add "$file"
        fi
    done <<< "$STAGED_SWIFT_FILES"
else
    echo -e "${YELLOW}⚠ SwiftFormat not found, skipping formatting${NC}"
fi

if command -v swiftlint &> /dev/null; then
    echo "🔎 Running SwiftLint..."

    LINT_ERRORS=0
    while IFS= read -r file; do
        if [ -f "$file" ]; then
            swiftlint lint --fix "$file" 2>/dev/null || true

            if ! swiftlint lint --quiet "$file" 2>/dev/null; then
                LINT_ERRORS=$((LINT_ERRORS + 1))
                echo -e "${RED}✗ Lint errors in: $file${NC}"
            fi
        fi
    done <<< "$STAGED_SWIFT_FILES"

    while IFS= read -r file; do
        if [ -f "$file" ]; then
            git add "$file"
        fi
    done <<< "$STAGED_SWIFT_FILES"

    if [ $LINT_ERRORS -gt 0 ]; then
        echo -e "${RED}✗ SwiftLint found errors that couldn't be auto-fixed${NC}"
        echo "Run 'swiftlint' to see details"
        exit 1
    fi

    echo -e "${GREEN}✓ SwiftLint passed${NC}"
else
    echo -e "${YELLOW}⚠ SwiftLint not found, skipping lint check${NC}"
fi

echo -e "${GREEN}✓ Pre-commit checks passed${NC}"
exit 0
