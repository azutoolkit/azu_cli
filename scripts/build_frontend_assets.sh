#!/bin/sh
# Refresh the precompiled CSS shipped by azu new. Generated apps use the same
# package-lock and npm scripts, and scan their own templates when customized.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
TEMPLATES="$ROOT/src/azu_cli/templates"
node "$ROOT/scripts/frontend_classes.mjs"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
cp "$TEMPLATES/project/package.json" "$TEMPLATES/project/package-lock.json" "$WORK/"
cp -R "$TEMPLATES/project/frontend" "$TEMPLATES/project/public" "$WORK/"
# Include every generator's classes in the ready-to-run stylesheet, even before
# a fresh app has auth or scaffolds. These examples never ship in generated apps.
mkdir -p "$WORK/public/templates/generator-examples"
cp -R "$TEMPLATES/scaffold/public/templates" "$WORK/public/templates/generator-examples/scaffold"
cp -R "$TEMPLATES/auth/public/templates" "$WORK/public/templates/generator-examples/auth"
cd "$WORK"
npm ci --ignore-scripts --no-audit --no-fund
npm run build:css
cp public/assets/app.css "$TEMPLATES/project/public/assets/app.css"
