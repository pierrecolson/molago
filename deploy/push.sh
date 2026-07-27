#!/usr/bin/env bash
# Déploie Molago sur le VPS Hostinger.
#
#   ./deploy/push.sh            envoie le code, (re)démarre le serveur de fichiers
#   ./deploy/push.sh --build    en plus, reconstruit l'image de la fabrique
#   ./deploy/push.sh --run      en plus, fabrique la journée tout de suite
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
# prouver qu'on est cet utilisateur changera — pas l'arborescence, pas la
# fabrique, pas l'app.
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
rsync -az --delete \
  --exclude 'out/' --exclude 'data/' \
  "$LOCAL/pipeline/" "$VPS:$REMOTE/pipeline/"
rsync -az \
  --exclude 'data/' --exclude '.env' \
  "$LOCAL/deploy/" "$VPS:$REMOTE/"

step "Envoi de la configuration"
# Les clés voyagent par stdin plutôt que par la ligne de commande : un argument
# de commande se retrouve dans les logs et dans `ps`.
grep -E '^(OPENROUTER_API_KEY|GOOGLE_TTS_API_KEY|MOLAGO_USER_ID|MOLAGO_SECRET_PATH|THIINGS_API_KEY|THIINGS_URL)=' "$LOCAL/.env" \
  | ssh "$VPS" "cat > $REMOTE/.env && chmod 600 $REMOTE/.env"
echo "  .env déposé (600)"

# La clé de l'API Thiings est déjà sur le serveur, dans le conteneur qui tourne.
# On l'y prend plutôt que de la faire transiter par une machine de développement
# ou par le dépôt : elle ne quitte jamais le VPS.
ssh "$VPS" '
  KEY=$(docker inspect thiings-api --format "{{range .Config.Env}}{{println .}}{{end}}" 2>/dev/null | grep "^API_KEY=" | cut -d= -f2-)
  if [ -n "$KEY" ] && ! grep -q "^THIINGS_API_KEY=" '"$REMOTE"'/.env; then
    printf "THIINGS_API_KEY=%s\n" "$KEY" >> '"$REMOTE"'/.env
    echo "  clé Thiings reprise du conteneur voisin"
  fi
  mkdir -p '"$REMOTE"'/data/icons
'

step "Serveur de fichiers"
ssh "$VPS" "cd $REMOTE && docker compose up -d files"

if [[ " $* " == *" --build "* || " $* " == *" --run "* ]]; then
  step "Construction de la fabrique"
  ssh "$VPS" "cd $REMOTE && docker compose build pipeline"
fi

if [[ " $* " == *" --run "* ]]; then
  step "Fabrication de la journée"
  ssh "$VPS" "cd $REMOTE && docker compose run --rm pipeline"
fi

step "Vérification"
DATE=$(date +%F)
CODE=$(curl -s -o /dev/null -w '%{http_code}' -m 20 "https://$HOST/u/$USER_ID/$DATE.json" || echo 000)
ROOT=$(curl -s -o /dev/null -w '%{http_code}' -m 20 "https://$HOST/" || echo 000)
echo "  journée du $DATE : HTTP $CODE   (404 = pas encore fabriquée)"
echo "  racine sans identifiant      : HTTP $ROOT   (404 attendu)"
echo
echo "  base URL de l'app : https://$HOST/u/$USER_ID/"
