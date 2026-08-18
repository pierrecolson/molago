#!/usr/bin/env bash
# Déploie Molago sur le VPS Hostinger.
#
#   ./deploy/push.sh            envoie le code, (re)démarre les deux services
#   ./deploy/push.sh --build    en plus, reconstruit l'API
#
# Idempotent : relancé, il ne duplique rien.

set -euo pipefail

VPS=root@srv1405219.hstgr.cloud
REMOTE=/root/molago
HOST=molago.srv1405219.hstgr.cloud
LOCAL="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

step() { printf '\n\033[1m▸ %s\033[0m\n' "$1"; }

# ── l'identifiant d'utilisateur ──────────────────────────────────────────────
# Ce n'est pas un chemin secret, c'est un identifiant : le contenu vit sous
# /u/<id>/, exactement là où il vivra quand les comptes existeront. Aujourd'hui
# il est seulement imprévisible, ce qui tient lieu d'authentification tant qu'il
# n'y a qu'un utilisateur. Quand Google OAuth arrivera, seule la façon de
# prouver qu'on est cet utilisateur changera — pas l'arborescence ni l'app.
#
# MOLAGO_SECRET_PATH est accepté comme ancien nom : renommer une clé dans .env
# n'apporte rien et casse un déploiement en cours.
if ! grep -qE '^MOLAGO_(USER_ID|SECRET_PATH)=..' "$LOCAL/.env" 2>/dev/null; then
  step "Génération de l'identifiant d'utilisateur"
  printf '\nMOLAGO_USER_ID=%s\n' "$(openssl rand -hex 12)" >> "$LOCAL/.env"
  echo "  écrit dans .env"
fi
USER_ID=$(grep -E '^MOLAGO_(USER_ID|SECRET_PATH)=' "$LOCAL/.env" | head -1 | cut -d= -f2- | tr -d "\"' ")

step "Envoi du code"
ssh "$VPS" "mkdir -p $REMOTE/data/u/$USER_ID"
rsync -az --delete "$LOCAL/api/" "$VPS:$REMOTE/api/"
rsync -az \
  --exclude 'data/' --exclude '.env' \
  "$LOCAL/deploy/" "$VPS:$REMOTE/"

step "Envoi de la configuration"
# Les clés voyagent par stdin plutôt que par la ligne de commande : un argument
# de commande se retrouve dans les logs et dans `ps`.
grep -E '^(OPENROUTER_API_KEY|SUPADATA_API_KEY|YOUTUBE_API_KEY|MOLAGO_USER_ID|MOLAGO_SECRET_PATH)=' "$LOCAL/.env" \
  | ssh "$VPS" "cat > $REMOTE/.env && chmod 600 $REMOTE/.env"
echo "  .env déposé (600)"

if [[ " $* " == *" --build "* ]]; then
  step "Construction de l'API"
  ssh "$VPS" "cd $REMOTE && docker compose build api"
fi

# Après la construction, jamais avant : remonter les services d abord laissait
# tourner l ancienne image, et le code fraîchement déployé restait invisible.
step "Services"
ssh "$VPS" "cd $REMOTE && docker compose up -d --remove-orphans files api"

step "Vérification"
CODE=$(curl -s -o /dev/null -w '%{http_code}' -m 20 "https://$HOST/u/$USER_ID/library" || echo 000)
ROOT=$(curl -s -o /dev/null -w '%{http_code}' -m 20 "https://$HOST/" || echo 000)
echo "  bibliothèque              : HTTP $CODE   (200 attendu)"
echo "  racine sans identifiant      : HTTP $ROOT   (404 attendu)"
echo
echo "  base URL de l'app : https://$HOST/u/$USER_ID/"
