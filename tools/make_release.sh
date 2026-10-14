#!/usr/bin/env bash
# Builds a clean release zip from git-tracked files, minus everything listed in
# RELEASE_EXCLUDE.txt, then verifies the archive. Usage: tools/make_release.sh NAME VERSION OUTDIR
set -euo pipefail
cd "$(dirname "$0")/.."
NAME="$1"; VER="$2"; OUT="$3"
ZIP="$OUT/$NAME-$VER.zip"
mkdir -p "$OUT"
if [ -n "$(git status --porcelain)" ]; then echo "working tree not clean; commit first"; exit 1; fi
mapfile -t EXCL < <(grep -v '^\s*#' RELEASE_EXCLUDE.txt | sed '/^\s*$/d')
EXCL+=("RELEASE_EXCLUDE.txt" ".gitattributes" ".gitignore")
STAGE="$(mktemp -d)/$NAME"
mkdir -p "$STAGE"
git ls-files -z | while IFS= read -r -d '' f; do
  skip=0
  for e in "${EXCL[@]}"; do
    case "$e" in */) [[ "$f" == "$e"* ]] && skip=1 ;; *) [[ "$f" == "$e" ]] && skip=1 ;; esac
  done
  [ $skip -eq 0 ] && { mkdir -p "$STAGE/$(dirname "$f")"; cp "$f" "$STAGE/$f"; }
done
rm -f "$ZIP"
python3 -I - "$(dirname "$STAGE")" "$NAME" "$ZIP" <<'PY'
import os, sys, zipfile
base, name, out = sys.argv[1:4]
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
    for root, dirs, files in os.walk(os.path.join(base, name)):
        dirs.sort()
        for f in sorted(files):
            full = os.path.join(root, f)
            z.write(full, os.path.relpath(full, base))
PY
# verify
LIST="$(python3 -I -c 'import sys, zipfile; print("\n".join(zipfile.ZipFile(sys.argv[1]).namelist()))' "$ZIP")"
BAD=0
for e in "${EXCL[@]}"; do
  if echo "$LIST" | grep -q "^$NAME/$e"; then echo "VERIFY FAIL: excluded path in zip: $e"; BAD=1; fi
done
REQ="LICENSE CREDITS.md ASSET_LICENSES.md README.md CHANGELOG.md project.godot tests/run_tests.gd tests/expected.json"
[ -f EULA-Pro.md ] && REQ="$REQ EULA-Pro.md"
for req in $REQ; do
  echo "$LIST" | grep -qx "$NAME/$req" || { echo "VERIFY FAIL: missing $req"; BAD=1; }
done
echo "$LIST" | grep -Eq '(^|/)\.godot/' && { echo "VERIFY FAIL: .godot/ editor cache in zip"; BAD=1; } || true
if [ -f EULA-Pro.md ]; then grep -q "Permission is hereby granted, free of charge" LICENSE && { echo "VERIFY FAIL: Pro LICENSE is still the MIT text"; BAD=1; }
else grep -q "Permission is hereby granted, free of charge" LICENSE || { echo "VERIFY FAIL: Lite LICENSE is not MIT"; BAD=1; }; fi
[ $BAD -eq 0 ] && echo "OK $ZIP $(du -h "$ZIP" | cut -f1) $(echo "$LIST" | grep -vc '/$') files" || exit 1
