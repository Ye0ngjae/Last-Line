#!/bin/sh
# Pushes last-line/build/web (exported from the Godot editor) to the gh-pages branch.
set -e
cd "$(dirname "$0")"
remote=$(git remote get-url origin)
dir=last-line/build/web
[ -f "$dir/index.html" ] || { echo "먼저 Godot 에디터에서 Web을 $dir/ 로 내보내세요"; exit 1; }
cd "$dir"
touch .nojekyll
rm -rf .git
git init -q -b gh-pages
git add -A
git commit -qm "deploy $(date +%F_%T)"
git push -f "$remote" gh-pages
rm -rf .git
echo "완료: https://ye0ngjae.github.io/Last-Line/"
