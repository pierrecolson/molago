#!/usr/bin/env bash
# Envoie Molago sur TestFlight.
#
#   ./app/testflight.sh
#
# Construit une archive signée pour la distribution, l'exporte en .ipa, et
# l'envoie à App Store Connect. Une fois traitée (5–20 min), la version apparaît
# dans TestFlight pour les testeurs internes.
#
# Prérequis, faits une fois par machine :
#
#   1. la fiche de l'app existe dans App Store Connect (l'API ne sait pas la
#      créer) ;
#   2. la clé ci-dessous est en place ;
#   3. le trousseau contient une identité « Apple Distribution », et
#      ~/Library/MobileDevice/Provisioning Profiles/ contient le profil
#      « Molago App Store ».
#
# Le point 3 n'était pas nécessaire tant qu'Xcode signait dans le nuage. Il
# refuse désormais (« Cloud signing permission error ») : la signature dans le
# nuage réclame un rôle que la clé n'a pas. Le certificat et le profil se
# fabriquent alors à la main, une fois par an, sur l'API App Store Connect —
# POST /v1/certificates (type DISTRIBUTION, avec un CSR openssl) puis
# POST /v1/profiles (type IOS_APP_STORE). Le .p12 s'importe avec
# `openssl pkcs12 -export -legacy` : sans `-legacy`, `security import` refuse
# le fichier qu'OpenSSL 3 produit.

set -euo pipefail

# Le dossier où vit ce script. Le chemin était écrit en dur, et le jour où le
# dépôt a déménagé plus rien ne partait. Un script qui se trouve tout seul
# marche aussi depuis un worktree, où le travail en cours se fait souvent.
APP=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TEAM=7R46U8G25A
KEY_ID=3C4JHJ4C7R
KEY_ISSUER=491cc229-3432-481d-b5c9-c59b58cad18e
KEY_PATH=~/.appstoreconnect/private_keys/AuthKey_$KEY_ID.p8

# App Store Connect refuse un numéro de build déjà vu, pour toujours. L'horodatage
# règle la question sans compteur à tenir : il ne recule jamais et ne se répète
# pas. Le numéro que lisent les testeurs, lui, reste MARKETING_VERSION.
# Trois groupes d'au plus quatre chiffres : la forme qu'Apple accepte.
BUILD=$(date +%Y.%m%d.%H%M)

# La clé sert à l'archive, qui fabrique encore seule son certificat de
# développement, puis à altool pour l'envoi. L'export, lui, signe à la main.
AUTH=(-authenticationKeyPath "$KEY_PATH"
      -authenticationKeyID "$KEY_ID"
      -authenticationKeyIssuerID "$KEY_ISSUER")

step() { printf '\n\033[1m▸ %s\033[0m\n' "$1"; }

step "Projet"
(cd "$APP" && xcodegen >/dev/null)

step "Archive (build $BUILD)"
rm -rf "$APP/build/Molago.xcarchive" "$APP/build/export"
xcodebuild -project "$APP/Molago.xcodeproj" -scheme Molago \
  -destination "generic/platform=iOS" \
  -archivePath "$APP/build/Molago.xcarchive" \
  -allowProvisioningUpdates "${AUTH[@]}" \
  CURRENT_PROJECT_VERSION="$BUILD" \
  archive 2>&1 | grep -E "error:|ARCHIVE (SUCCEEDED|FAILED)" || true
[ -d "$APP/build/Molago.xcarchive" ] || { echo "✕ l'archive n'a pas été produite"; exit 1; }

step "Export"
cat >"$APP/build/export.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>teamID</key><string>7R46U8G25A</string>
  <key>signingStyle</key><string>manual</string>
  <key>signingCertificate</key><string>Apple Distribution</string>
  <key>provisioningProfiles</key>
  <dict><key>com.molago.app</key><string>Molago App Store</string></dict>
  <key>uploadSymbols</key><true/>
</dict></plist>
PLIST
# Signature à la main, avec le certificat et le profil du trousseau : la
# signature dans le nuage échoue sur un défaut de permission de la clé, et
# `-allowProvisioningUpdates` ne fait alors que masquer la cause derrière un
# « No profiles for 'com.molago.app' were found » trompeur.
xcodebuild -exportArchive \
  -archivePath "$APP/build/Molago.xcarchive" \
  -exportPath "$APP/build/export" \
  -exportOptionsPlist "$APP/build/export.plist" 2>&1 \
  | grep -E "error:|EXPORT (SUCCEEDED|FAILED)" || true

IPA=$(ls "$APP"/build/export/*.ipa 2>/dev/null | head -1)
[ -n "$IPA" ] || { echo "✕ pas de .ipa exporté"; exit 1; }

step "Envoi"
xcrun altool --upload-app -f "$IPA" -t ios \
  --apiKey "$KEY_ID" --apiIssuer "$KEY_ISSUER"

echo
echo "  Envoyé — build $BUILD. Apple le traite en 5 à 20 minutes,"
echo "  puis il apparaît dans TestFlight sur l'iPhone du testeur."
