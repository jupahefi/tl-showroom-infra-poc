#!/bin/bash

set -e  # ⛔ Detener ejecución si hay error

# 📌 Cargar variables desde `.env`
ENV_FILE=".env"
if [[ -f "$ENV_FILE" ]]; then
    set -a
    source "$ENV_FILE"
    set +a
else
    echo "❌ ERROR: No se encontró el archivo .env. Ejecuta 'init.sh' primero."
    exit 1
fi

echo "✅ Variables de entorno cargadas correctamente."

echo "🚀 Iniciando despliegue de Repositorios para backend y frontend..."

# 📌 Configurar Git para usar HTTPS en lugar de SSH
git config --global url."https://github.com/".insteadOf "git@github.com:"

# 🔑 URLs HTTPS en lugar de SSH
BACKEND_REPO_URL="https://github.com/$GITHUB_USER/$BACKEND_REPO.git"
FRONTEND_REPO_URL="https://github.com/$GITHUB_USER/$FRONTEND_REPO.git"

# 🚀 Función para crear el repo en GitHub si no existe
create_github_repo() {
    local repo_name="$1"
    echo "🔍 Verificando si el repositorio $repo_name existe en GitHub..."

    if ! gh repo view "$GITHUB_USER/$repo_name" &>/dev/null; then
        echo "⚠️ El repositorio no existe. Creándolo en GitHub..."
        gh repo create "$GITHUB_USER/$repo_name" --private --confirm
    else
        echo "✅ El repositorio $repo_name ya existe en GitHub."
    fi
}

# 🚀 Función para inicializar y sincronizar un repositorio
init_repo() {
    local repo_path="$1"
    local repo_url="$2"
    local repo_name="$3"

    create_github_repo "$repo_name"

    echo "📂 Navegando a $repo_path..."
    cd "$repo_path"

    # 🚫 Eliminar cualquier repositorio Git existente
    if [ -d ".git" ]; then
        echo "🧹 Eliminando repositorio Git existente..."
        rm -rf .git
    fi

    echo "🛠️ Inicializando repositorio Git desde cero..."
    git init
    git checkout -b main
    git remote add origin "$repo_url"

    echo "📦 Agregando archivos al nuevo repositorio..."
    git add .
    git commit -m "🚀 Versión inicial del repositorio desde script automatizado"

    echo "📤 Forzando push inicial a GitHub..."
    git push -u origin main --force
}

# 🏗️ Crear repos y subir código de manera flexible
init_repo "/opt/easyengine/sites/$FULL_DOMAIN/app/backend" "$BACKEND_REPO_URL" "$BACKEND_REPO"
init_repo "/opt/frontend/showroom-frontend" "$FRONTEND_REPO_URL" "$FRONTEND_REPO"

# 📌 Crear los scripts de despliegue en los repositorios
echo "📜 Creando scripts de despliegue..."

# 📌 Función para limpiar el dominio (quitar puntos `.`)
clean_domain() {
    echo "$1" | tr -d '.'
}

# 📌 Generar el nombre correcto de la red de EasyEngine
NETWORK_NAME="ee-global-frontend-network"

# 🚀 Backend Deploy Script
cat <<EOF > "/opt/easyengine/sites/$FULL_DOMAIN/app/backend/deploy.sh"
#!/bin/bash

set -e

echo "🚀 Iniciando despliegue del backend..."

PROJECT_PATH="/opt/easyengine/sites/$FULL_DOMAIN/app/backend"
cd "$PROJECT_PATH"

echo "📥 Actualizando código fuente desde Git..."
git pull origin main

echo "🐳 Construyendo imagen de Docker..."
docker-compose build --no-cache

echo "🔄 Reiniciando backend..."
docker-compose down
docker-compose up -d

echo "🔍 Verificando estado del backend..."
docker ps | grep showroom-api

echo "🔗 Conectando backend a la red de EasyEngine..."
if docker network connect $NETWORK_NAME showroom-api; then
    echo "✅ Conexión de red exitosa."
else
    echo "⚠️ Advertencia: No se pudo conectar showroom-api a la red de EasyEngine. Verifica manualmente."
fi

echo "✅ Despliegue del backend completado."
EOF

chmod +x "/opt/easyengine/sites/$FULL_DOMAIN/app/backend/deploy.sh"

# 🚀 Frontend Deploy Script
cat <<EOF > /opt/frontend/showroom-frontend/deploy.sh
#!/bin/bash

set -e

echo "🚀 Iniciando despliegue del frontend..."

FRONTEND_DIR="/opt/frontend/showroom-frontend"
cd "$FRONTEND_DIR"

echo "📥 Actualizando código fuente desde Git..."
git pull origin main

echo "📦 Instalando dependencias..."
npm install

echo "🏗️ Construyendo frontend..."
npm run build

echo "📂 Moviendo archivos estáticos a /htdocs..."
rsync -av --delete dist/ "/opt/easyengine/sites/$FULL_DOMAIN/app/htdocs/"

echo "🔄 Recargando Nginx..."
ee site reload "$FULL_DOMAIN"

echo "🔗 Conectando backend a la red de EasyEngine..."
if docker network connect $NETWORK_NAME showroom-api; then
    echo "✅ Conexión de red exitosa."
else
    echo "⚠️ Advertencia: No se pudo conectar showroom-api a la red de EasyEngine. Verifica manualmente."
fi

echo "✅ Despliegue del frontend completado."
EOF

chmod +x /opt/frontend/showroom-frontend/deploy.sh

# 📦 Agregar archivos y hacer commit
echo "📦 Agregando archivos y haciendo commit..."
cd "/opt/easyengine/sites/$FULL_DOMAIN/app/backend"
git add deploy.sh
git commit -m "Agregar script de despliegue del backend" || echo "⚠️ No hay cambios para commitear"
git push -u origin main || echo "⚠️ No se pudo hacer push, revisar conflictos."

cd "/opt/frontend/showroom-frontend"
git add deploy.sh
git commit -m "Agregar script de despliegue del frontend" || echo "⚠️ No hay cambios para commitear"
git push -u origin main || echo "⚠️ No se pudo hacer push, revisar conflictos."

echo "🎉 Repositorios actualizados con los scripts de despliegue."
