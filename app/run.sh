#!/usr/bin/env bash
# Construit Molago et l'ouvre dans le simulateur.
#
#   ./app/run.sh              construit, installe, lance, ouvre le simulateur
#   ./app/run.sh --clean      repart d'une installation neuve (vide le carnet)
#   ./app/run.sh --device     installe sur l'iPhone branché plutôt que le simulateur
#
# Idempotent : relancé, il remplace l'app sans toucher aux données.

set -euo pipefail

APP=/Users/pierre/Claude/code/molago/app
BUNDLE=com.pierrecolson.molago
DEVICE="iPhone 17 Pro"

step() { printf '\n\033[1m▸ %s\033[0m\n' "$1"; }

# ── l'iPhone ────────────────────────────────────────────────────────────────
# Même geste que pour le simulateur : on retrouve l'appareil, on construit, on
# installe, on lance. Rien à faire dans Xcode.
if [[ " $* " == *" --device "* ]]; then
  step "iPhone"
  # Deux identifiants pour le même téléphone, et ils ne sont pas
  # interchangeables : xcodebuild veut l'UDID matériel, devicectl son propre
  # UUID. On prend chacun à sa source plutôt que d'en deviner un.
  (cd "$APP" && xcodegen >/dev/null)
  UDID=$(xcodebuild -project "$APP/Molago.xcodeproj" -scheme Molago -showdestinations 2>/dev/null \
    | grep "platform:iOS," | grep -v placeholder \
    | sed -E 's/.*id:([0-9A-Za-z-]+).*/\1/' | head -1)
  CTL=$(xcrun devicectl list devices 2>/dev/null | grep -i connected \
    | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' | head -1)
  if [ -z "$UDID" ] || [ -z "$CTL" ]; then
    echo "✕ aucun iPhone utilisable."
    echo "  Branche-le en USB, déverrouille-le, accepte « Se fier », et vérifie que"
    echo "  le Mode développeur est activé (Réglages → Confidentialité et sécurité)."
    exit 1
  fi
  echo "  $(xcrun devicectl list devices 2>/dev/null | grep -i connected | sed -E 's/  +.*//' | head -1)"

  step "Construction"
  # Viser l'appareil précis, et pas « iOS en général » : c'est ce qui fait
  # enregistrer le téléphone dans l'équipe et fabriquer le profil.
  xcodebuild -project "$APP/Molago.xcodeproj" -scheme Molago \
    -destination "platform=iOS,id=$UDID" \
    -derivedDataPath "$APP/build" \
    -allowProvisioningUpdates build 2>&1 \
    | grep -E "error:|BUILD (SUCCEEDED|FAILED)" || true

  APP_PATH="$APP/build/Build/Products/Debug-iphoneos/Molago.app"
  [ -d "$APP_PATH" ] || { echo "✕ la construction n'a rien produit"; exit 1; }

  step "Installation"
  xcrun devicectl device install app --device "$CTL" "$APP_PATH" >/dev/null
  xcrun devicectl device process launch --device "$CTL" com.pierrecolson.molago >/dev/null

  echo
  echo "  Molago est sur ton iPhone. Il y reste — le profil n'expire plus."
  exit 0
fi

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
