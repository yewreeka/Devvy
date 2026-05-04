#!/usr/bin/env bash
# Lints Swift files that changed on the branch before pushing.

set -euo pipefail

PROTECTED_BRANCHES=("main" "master")

current_branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")
for protected in "${PROTECTED_BRANCHES[@]}"; do
	if [ "$current_branch" = "$protected" ]; then
		echo "❌ Direct push to '$protected' is not allowed"
		echo ""
		echo "Please create a feature branch and submit a PR:"
		echo "  git checkout -b feature/your-feature-name"
		echo "  git push -u origin feature/your-feature-name"
		exit 1
	fi
done

if ! command -v swiftlint &> /dev/null; then
	echo "❌ SwiftLint is not installed"
	echo "Please install SwiftLint using:"
	echo "  brew install swiftlint"
	exit 1
fi

z40=0000000000000000000000000000000000000000
git_root="$(git rev-parse --show-toplevel)"

while read -r local_ref local_sha remote_ref remote_sha; do
	if [ "$local_sha" = "$z40" ]; then
		continue
	fi

	if [ "$remote_sha" = "$z40" ]; then
		if git rev-parse --verify origin/main >/dev/null 2>&1; then
			base_sha="origin/main"
		elif git rev-parse --verify origin/master >/dev/null 2>&1; then
			base_sha="origin/master"
		else
			base_sha="$local_sha^"
		fi
	else
		base_sha="$remote_sha"
	fi

	changed_files=()
	while IFS= read -r file; do
		if [ -f "$git_root/$file" ]; then
			changed_files+=("$git_root/$file")
		fi
	done < <(git diff --name-only --diff-filter=d "$base_sha" "$local_sha" 2>/dev/null | grep '\.swift$' || true)

	if [ ${#changed_files[@]} -eq 0 ]; then
		echo "✅ No Swift files changed, skipping lint"
		continue
	fi

	echo "🔎 Linting ${#changed_files[@]} changed Swift file(s)..."

	if swiftlint lint --strict --config "$git_root/.swiftlint.yml" "${changed_files[@]}"; then
		echo "✅ No SwiftLint violations, pushing!"
	else
		echo ""
		echo "❌ Found SwiftLint violations, fix them before pushing."
		exit 1
	fi
done

exit 0
