#!/usr/bin/env bash
# Construit Molago et l'ouvre dans le simulateur.
#
#   ./app/run.sh              construit, installe, lance, ouvre le simulateur
#   ./app/run.sh --clean      repart d'une installation neuve (vide le carnet)
#
# Idempotent : relancé, il remplace l'app sans toucher aux données.

set -euo pipefail

APP=/Users/pierre/Claude/code/molago/app
BUNDLE=com.pierrecolson.Molago
DEVICE="iPhone 17 Pro"

step() { printf '\n\033[1m▸ %s\033[0m\n' "$1"; }

# L'identifiant du simulateur est retrouvé par son nom : il change d'une
# machine à l'autre, et le coder en dur casse dès qu'on change d'appareil.
SIM=$(xcrun simctl list devices available \
  | grep -m1 "$DEVICE (" \
  | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
[ -n "$SIM" ] || { echo "✕ simulateur « $DEVICE » introuvable"; exit 1; }

step "Projet"
# Le .xcodeproj n'est pas versionné : il se régénère depuis project.yml.
(cd "$APP" && xcodegen >/dev/null)

step "Construction"
xcodebuild -project "$APP/Molago.xcodeproj" -scheme Molago \
  -destination "platform=iOS Simulator,name=$DEVICE" \
  -derivedDataPath "$APP/build" build 2>&1 \
  | grep -E "error:|warning: .*deprecated|BUILD (SUCCEEDED|FAILED)" || true

step "Simulateur"
xcrun simctl boot "$SIM" 2>/dev/null || true
xcrun simctl bootstatus "$SIM" -b >/dev/null 2>&1 || true
xcrun simctl terminate "$SIM" "$BUNDLE" 2>/dev/null || true

if [[ " $* " == *" --clean "* ]]; then
  echo "  installation neuve — le carnet local est vidé"
  xcrun simctl uninstall "$SIM" "$BUNDLE" 2>/dev/null || true
fi

xcrun simctl install "$SIM" "$APP/build/Build/Products/Debug-iphonesimulator/Molago.app"
xcrun simctl launch "$SIM" "$BUNDLE" >/dev/null
open -a Simulator

echo
echo "  Molago tourne. Premier lancement : quelques secondes de téléchargement."
