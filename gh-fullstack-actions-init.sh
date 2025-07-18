#!/bin/bash

set -e  # ⛔ Detener ejecución si hay error

# 📌 Cargar variables desde `.env`
ENV_FILE=".env"
if [[ -f "$ENV_FILE" ]]; then
    while IFS='=' read -r key value; do
        if [[ "$key" =~ ^[A-Z_][A-Z0-9_]*$ ]]; then
            value="${value#\'}"
            value="${value%\'}"
            export "$key=$value"
        fi
    done < <(grep -v '^#' "$ENV_FILE")
else
    echo "❌ ERROR: No se encontró el archivo .env. Ejecuta 'init.sh' primero."
    exit 1
fi

echo "✅ Variables de entorno cargadas correctamente."

# 📂 Rutas en el servidor
BACKEND_PATH="/opt/easyengine/sites/$FULL_DOMAIN/app/backend"
FRONTEND_PATH="/opt/frontend/showroom-frontend"

# ✅ DEBUG: Mostrar variables
echo "🔍 DEBUG: VARIABLES"
echo "📌 GITHUB_USER: $GITHUB_USER"
echo "📌 BACKEND_REPO: $BACKEND_REPO"
echo "📌 FRONTEND_REPO: $FRONTEND_REPO"
echo "📌 SERVER_IP: $SERVER_IP"
echo "📌 SERVER_USER: $SERVER_USER"
echo "📌 BACKEND_PATH: $BACKEND_PATH"
echo "📌 FRONTEND_PATH: $FRONTEND_PATH"
echo "---------------------------"

# ❓ Preguntar si se debe generar nuevas claves SSH
read -p "🔄 ¿Quieres generar nuevas claves SSH? (Y/n): " GENERATE_KEYS
GENERATE_KEYS=${GENERATE_KEYS:-y}  # Valor por defecto "y"

if [[ "$GENERATE_KEYS" =~ ^[Yy]$ ]]; then
    echo "🔑 Generando claves SSH para GitHub Actions..."
    ssh-keygen -t rsa -b 4096 -C "deploy-backend@github-actions" -f github_actions_key_backend -N ""
    ssh-keygen -t rsa -b 4096 -C "deploy-frontend@github-actions" -f github_actions_key_frontend -N ""

    echo "🔄 Convirtiendo claves a formato PEM..."
    ssh-keygen -p -m PEM -f github_actions_key_backend -N "" -q
    ssh-keygen -p -m PEM -f github_actions_key_frontend -N "" -q

    echo "✅ Claves SSH generadas y convertidas a formato PEM"

    # 🔍 DEBUG: Validar claves generadas
    echo "🔍 Validando formato de las claves..."
    file github_actions_key_backend
    file github_actions_key_frontend

    echo "🔑 Agregando claves públicas al usuario actual en el servidor..."
    mkdir -p ~/.ssh
    cat github_actions_key_backend.pub >> ~/.ssh/authorized_keys
    cat github_actions_key_frontend.pub >> ~/.ssh/authorized_keys
    chmod 600 ~/.ssh/authorized_keys
    echo "✅ Claves agregadas a ~/.ssh/authorized_keys"
else
    echo "⏩ Omitiendo la generación de claves SSH..."
fi

# 🔐 Subir claves privadas y públicas a GitHub Secrets
echo "🔐 Subiendo claves a GitHub Secrets..."
gh secret set SSH_PRIVATE_KEY_BACKEND --body "$(cat github_actions_key_backend)" --repo "$GITHUB_USER/$BACKEND_REPO"
gh secret set SSH_PUBLIC_KEY_BACKEND --body "$(cat github_actions_key_backend.pub)" --repo "$GITHUB_USER/$BACKEND_REPO"

gh secret set SSH_PRIVATE_KEY_FRONTEND --body "$(cat github_actions_key_frontend)" --repo "$GITHUB_USER/$FRONTEND_REPO"
gh secret set SSH_PUBLIC_KEY_FRONTEND --body "$(cat github_actions_key_frontend.pub)" --repo "$GITHUB_USER/$FRONTEND_REPO"

echo "✅ Claves privadas y públicas almacenadas en GitHub Secrets."

# 🛠 **Eliminar workflows previos y crear nuevos**
WORKFLOW_DIR=".github/workflows"
for REPO_PATH in "$BACKEND_PATH" "$FRONTEND_PATH"; do
    echo "🗑️ Eliminando archivos de workflows en $REPO_PATH..."
    rm -rf "$REPO_PATH/$WORKFLOW_DIR"
    mkdir -p "$REPO_PATH/$WORKFLOW_DIR"

    echo "📄 Creando nuevo workflow en $REPO_PATH..."
    cat <<EOF > "$REPO_PATH/$WORKFLOW_DIR/deploy.yml"
name: 🚀 Deploy to Server

on:
  push:
    branches:
      - main
  workflow_dispatch:

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - name: 📥 Checkout del código
        uses: actions/checkout@v3

      - name: 🔍 Configurar SSH
        run: |
          echo "🛠️ Preparando el entorno SSH..."
          mkdir -p ~/.ssh

          if [[ "$REPO_PATH" == "$BACKEND_PATH" ]]; then
            echo "\${{ secrets.SSH_PRIVATE_KEY_BACKEND }}" | tr -d '\r' > ~/.ssh/id_rsa
            echo "\${{ secrets.SSH_PUBLIC_KEY_BACKEND }}" | tr -d '\r' > ~/.ssh/id_rsa.pub
          else
            echo "\${{ secrets.SSH_PRIVATE_KEY_FRONTEND }}" | tr -d '\r' > ~/.ssh/id_rsa
            echo "\${{ secrets.SSH_PUBLIC_KEY_FRONTEND }}" | tr -d '\r' > ~/.ssh/id_rsa.pub
          fi

          chmod 600 ~/.ssh/id_rsa
          chmod 644 ~/.ssh/id_rsa.pub

          echo "🔍 Contenido de id_rsa.pub:"
          cat ~/.ssh/id_rsa.pub

          ssh-keyscan -H $SERVER_IP >> ~/.ssh/known_hosts

          echo "Host $SERVER_IP
                User $SERVER_USER
                IdentityFile ~/.ssh/id_rsa
                IdentitiesOnly yes
                PubKeyAcceptedAlgorithms +ssh-rsa
                HostKeyAlgorithms +ssh-rsa
                StrictHostKeyChecking no" > ~/.ssh/config

          chmod 600 ~/.ssh/config

          echo "🔍 Validando clave SSH..."
          ssh-keygen -lf ~/.ssh/id_rsa.pub || echo "⚠️ Error verificando clave pública"

          echo "🔍 Iniciando agente SSH..."
          eval "\$(ssh-agent -s)"
          ssh-add ~/.ssh/id_rsa || echo "⚠️ Error al añadir clave a ssh-agent"

          echo "🔍 Probando conexión SSH con el servidor..."
          ssh -T $SERVER_USER@$SERVER_IP || echo "⚠️ Error en conexión SSH"

      - name: 🚀 Desplegar en servidor
        run: |
          echo "🔄 Probando acceso al servidor antes del despliegue..."
          ssh -o StrictHostKeyChecking=no $SERVER_USER@$SERVER_IP "echo '✅ Acceso exitoso'"

          echo "📂 Cambiando al directorio de despliegue: $REPO_PATH"
          ssh $SERVER_USER@$SERVER_IP << 'EOF'
            cd $REPO_PATH
            echo "🔄 Haciendo pull de la última versión..."
            git pull origin main
            echo "🚀 Ejecutando script de despliegue..."
            bash deploy.sh
          EOF
EOF
    echo "✅ Workflow creado en $REPO_PATH/$WORKFLOW_DIR/deploy.yml"
done

# 🚀 **Subir los nuevos workflows a GitHub**
for REPO_PATH in "$BACKEND_PATH" "$FRONTEND_PATH"; do
    echo "🚀 Subiendo nuevos workflows a GitHub desde $REPO_PATH..."
    cd "$REPO_PATH"
    git add "$WORKFLOW_DIR"
    git commit -m "Reinicialización de GitHub Actions" || echo "⚠️ No hay cambios para commit"
    git push -f origin main || echo "⚠️ Error en git push, verificando conexión..."
done
echo "✅ Workflows reiniciados y desplegados."
