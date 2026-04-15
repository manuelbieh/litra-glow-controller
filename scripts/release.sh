#!/usr/bin/env bash
# Tag, build, and publish a GitHub release with the DMG attached.
# Usage: scripts/release.sh <version>    e.g. scripts/release.sh 0.1.0
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:-}"
if [[ -z "${VERSION}" ]]; then
  echo "usage: $0 <version>   (e.g. 0.1.0)" >&2
  exit 1
fi
if [[ ! "${VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.-]+)?$ ]]; then
  echo "error: '${VERSION}' is not valid semver" >&2
  exit 1
fi

TAG="v${VERSION}"
DMG="dist/LitraGlowController-${VERSION}.dmg"

command -v gh >/dev/null || { echo "error: GitHub CLI 'gh' not installed"; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "error: run 'gh auth login' first"; exit 1; }

if [[ -n "$(git status --porcelain)" ]]; then
  echo "error: working tree is dirty — commit or stash first" >&2
  git status --short >&2
  exit 1
fi

if git rev-parse -q --verify "refs/tags/${TAG}" >/dev/null; then
  echo "error: tag ${TAG} already exists locally" >&2
  exit 1
fi
if git ls-remote --exit-code --tags origin "${TAG}" >/dev/null 2>&1; then
  echo "error: tag ${TAG} already exists on origin" >&2
  exit 1
fi

echo "→ Building ${TAG}"
./scripts/build.sh "${VERSION}"

echo "→ Tagging and pushing ${TAG}"
git tag -a "${TAG}" -m "Release ${TAG}"
git push origin "${TAG}"

echo "→ Creating GitHub release"
gh release create "${TAG}" "${DMG}" \
  --title "${TAG}" \
  --generate-notes

echo "✓ Released ${TAG}"
gh release view "${TAG}" --web >/dev/null 2>&1 || true
