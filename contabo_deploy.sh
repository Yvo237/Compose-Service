#!/usr/bin/env bash
set -euo pipefail

# Configuration des repositories
ANALYTICS_REPO_URL="https://github.com/Yvo237/Analytics-Service.git"
INGESTION_REPO_URL="https://github.com/Yvo237/Ingestion-Service.git"
REPORTING_REPO_URL="https://github.com/Yvo237/Reporting-Service.git"
COMPOSE_REPO_URL="https://github.com/Yvo237/Compose-Service.git"

PROJECT_PATH="/home/$USER/Lan"
DOMAIN="158.220.97.53"
DB_USER="admin"
DB_PASSWORD="admin1234"
DB_NAME="analysis_db"

# Vérification des repositories
if [ "$ANALYTICS_REPO_URL" = "https://github.com/YOUR_USERNAME/Analytics-Service.git" ] || \
   [ "$INGESTION_REPO_URL" = "https://github.com/YOUR_USERNAME/Ingestion-Service.git" ] || \
   [ "$REPORTING_REPO_URL" = "https://github.com/YOUR_USERNAME/Reporting-Service.git" ] || \
   [ "$COMPOSE_REPO_URL" = "https://github.com/YOUR_USERNAME/Compose-Service.git" ]; then
  echo "ERROR: Modifie les URLs des repositories avant de continuer."
  exit 1
fi

if [ "$DOMAIN" = "YOUR_VPS_IP_OR_DOMAIN" ]; then
  echo "ERROR: Modifie DOMAIN dans le script avant de continuer (mettez l'IP de votre VPS)."
  exit 1
fi

mkdir -p "$PROJECT_PATH"
cd "$PROJECT_PATH"

# Installer Docker si nécessaire
if ! command -v docker >/dev/null 2>&1; then
  echo "Installation de Docker..."
  curl -fsSL https://get.docker.com | sh
fi

# Installer Docker Compose si nécessaire
if ! command -v docker-compose >/dev/null 2>&1 && ! docker compose version >/dev/null 2>&1; then
  echo "Installation de Docker Compose..."
  apt update
  apt install -y docker-compose-plugin
fi

# Cloner tous les repositories
clone_repo() {
  local repo_url=$1
  local target_dir=$2
  
  if [ ! -d "$target_dir" ]; then
    echo "Clonage de $repo_url vers $target_dir..."
    git clone "$repo_url" "$target_dir"
  else
    echo "Mise à jour de $target_dir..."
    cd "$target_dir"
    git pull origin main || git pull origin master
    cd "$PROJECT_PATH"
  fi
}

clone_repo "$ANALYTICS_REPO_URL" "Analytics-Service"
clone_repo "$INGESTION_REPO_URL" "Ingestion-Service"
clone_repo "$REPORTING_REPO_URL" "Reporting-Service"
clone_repo "$COMPOSE_REPO_URL" "Compose-Service"

cd "$PROJECT_PATH/Compose-Service"

# Créer le fichier .env pour Compose-Service
cat > .env <<EOF
# Configuration PostgreSQL
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD
DB_NAME=$DB_NAME

# Configuration des services
ENV=production

# URLs internes des services Docker
ANALYSIS_SERVICE_URL=http://analytics_service:8000/v1/analysis
DATA_COLLECTION_SERVICE_URL=http://ingestion_service:8001

# Configuration Celery
CELERY_BROKER_URL=redis://redis_queue:6379/0
CELERY_RESULT_BACKEND=redis://redis_queue:6379/0
EOF

# Construire et démarrer les services
docker compose up -d --build

# Vérifier l'état des conteneurs
docker compose ps

echo "\nDéploiement terminé."
echo "Backend disponible : http://$DOMAIN/v1/health"
echo "Si le domaine n'est pas encore configuré, teste localement depuis le VPS : http://localhost/v1/health"
echo ""
echo "🔗 Pour l'architecture hybride :"
echo "- Frontend Vercel : https://your-app.vercel.app"
echo "- Backend Contabo : http://$DOMAIN"
echo "- Mettez à jour VITE_API_URL dans Reporting-Service avec : http://$DOMAIN"
