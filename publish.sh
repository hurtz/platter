#!/bin/bash
# Builds Platter and publishes it to github.com/hurtz/platter (repo, release, GitHub Pages).
set -uo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
cd "$(dirname "$0")"
REPO=hurtz/platter
echo "== $(date)"
echo "== build"
bash build.sh || { echo "PUBLISH_FAIL build"; exit 1; }
cp -f dist/Platter-1.0.zip dist/Platter.zip
echo "== gh"
GH=$(command -v gh) || { echo "PUBLISH_FAIL no gh found"; exit 1; }
echo "gh at $GH"; gh --version | head -1
gh auth status 2>&1 | head -6
gh auth status >/dev/null 2>&1 || { echo "PUBLISH_FAIL gh not logged in"; exit 1; }
gh auth setup-git >/dev/null 2>&1 || true
echo "== git"
[ -d .git ] || git init -q -b main
git config user.name >/dev/null || git config user.name "Jason O'Connell"
git config user.email >/dev/null || git config user.email "hurtz@users.noreply.github.com"
git add -A
git commit -q -m "Platter 1.0: real hard drive sounds for your Mac

Menu bar app with six synthesized drives, live disk activity tracking,
activity LED, GitHub Pages site and demo video.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01WhKyDk7a7meq3nz2CJ7Zzr" || echo "(nothing new to commit)"
git log --oneline | head -3
echo "== repo"
if gh repo view "$REPO" >/dev/null 2>&1; then
  git remote get-url origin >/dev/null 2>&1 || git remote add origin "https://github.com/$REPO.git"
  git push -u origin main 2>&1 | tail -3
else
  gh repo create "$REPO" --public --source . --remote origin --push \
    --description "Real hard drive sounds for your Mac. A menu bar app with six synthesized drives that follows your real disk activity." \
    --homepage "https://hurtz.github.io/platter/" 2>&1 | tail -5
fi
gh repo edit "$REPO" --add-topic macos --add-topic menu-bar-app --add-topic swift --add-topic swiftui --add-topic nostalgia --add-topic hard-drive --add-topic retro --add-topic sound 2>&1 | tail -2
echo "== release"
if gh release view v1.0 -R "$REPO" >/dev/null 2>&1; then
  gh release upload v1.0 dist/Platter.zip dist/Platter-Promo.mp4 --clobber -R "$REPO" 2>&1 | tail -2
else
  gh release create v1.0 dist/Platter.zip dist/Platter-Promo.mp4 -R "$REPO" --title "Platter 1.0" --notes-file release-notes.md 2>&1 | tail -3
fi
echo "== pages"
gh api -X POST "repos/$REPO/pages" -f "source[branch]=main" -f "source[path]=/docs" 2>&1 | head -5
gh api "repos/$REPO/pages" --jq '.html_url + " status=" + (.status // "pending")' 2>&1 | head -3
echo "PUBLISH_OK"
