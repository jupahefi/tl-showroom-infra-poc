#!/bin/bash

set -e  # ⛔ Detener ejecución si hay error

# 📌 Variables requeridas
ENV_FILE=".env"
REQUIRED_VARS=("DB_USER" "DB_PASS" "DB_NAME" "SITE_DOMAIN" "SUBDOMAIN" "FASTAPI_PORT")

# 🛠️ Función para pedir input con valor por defecto
ask_var() {
    local var_name="$1"
    local default_value="$2"
    local user_input

    read -p "🔹 Ingresa $var_name [$default_value]: " user_input
    echo "${user_input:-$default_value}"
}

# 🛠️ Función para pedir contraseña sin mostrar en pantalla
ask_sensitive_var() {
    local var_name="$1"
    local default_value="$2"
    local user_input

    read -p "🔹 Ingresa $var_name (oculto, presiona Enter para usar el valor por defecto): " user_input
    echo "${user_input:-$default_value}"
}

# 📂 Verificación del archivo .env
if [[ -f "$ENV_FILE" ]]; then
    echo "⚠️ Archivo .env encontrado en $(pwd)."
    read -p "🔄 ¿Quieres regenerarlo? (s/n): " REGENERATE_ENV
    REGENERATE_ENV=${REGENERATE_ENV:-s}
    if [[ "$REGENERATE_ENV" == "s" ]]; then
        rm "$ENV_FILE"
        echo "🗑️ Archivo .env eliminado. Creando uno nuevo..."
    else
        echo "✅ Usando configuración existente en .env."
    fi
fi

# 📂 Si el .env no existe, lo creamos y pedimos valores
if [[ ! -f "$ENV_FILE" ]]; then
    printf "⚠️ No se encontró .env. Creando uno nuevo...\n"

    DB_USER=$(ask_var "usuario de la base de datos" "showroom_user")
    DB_PASS=$(ask_sensitive_var "contraseña de la base de datos" "")
    DB_NAME=$(ask_var "nombre de la base de datos" "showroom_db")
    SITE_DOMAIN=$(ask_var "dominio raíz (ej: equalitech.xyz)" "equalitech.xyz")
    SUBDOMAIN=$(ask_var "subdominio del sitio (ej: tl-showroom)" "tl-showroom")
    FASTAPI_PORT=$(ask_var "puerto para FastAPI" "8000")
    SERVER_USER=$(ask_var "usuario del servidor" "user")
    GIT_USER=$(ask_var "usuario de Git" "usuario")
    SERVER_IP=$(ask_var "IP del servidor" "0.0.0.0")

    # 🔹 Instalar GitHub CLI si no está presente
    if ! command -v gh &>/dev/null; then
        printf "🔹 Instalando GitHub CLI...\n"
        sudo apt update && sudo apt install -y gh
    fi

    # 🔑 Autenticar GitHub si no está autenticado
    if ! gh auth status &>/dev/null; then
        printf "🔑 Autenticando con GitHub...\n"
        gh auth login
    fi

    # 🔍 Obtener el usuario de GitHub automáticamente
    GITHUB_USER=$(gh auth status 2>/dev/null | grep -oP '(?<=Logged in to github.com as )[^ ]+' || echo $GIT_USER)

    # 🔹 Generar nombres de repositorios automáticamente
    BACKEND_REPO="${SUBDOMAIN}-backend-poc"
    FRONTEND_REPO="${SUBDOMAIN}-frontend-poc"

    FULL_DOMAIN="$SUBDOMAIN.$SITE_DOMAIN"

    # 📄 Guardar variables en `.env`
    printf "DB_USER='%s'\n" "$DB_USER" > "$ENV_FILE"
    printf "DB_PASS='%s'\n" "$DB_PASS" >> "$ENV_FILE"
    printf "DB_NAME='%s'\n" "$DB_NAME" >> "$ENV_FILE"
    printf "SITE_DOMAIN='%s'\n" "$SITE_DOMAIN" >> "$ENV_FILE"
    printf "SUBDOMAIN='%s'\n" "$SUBDOMAIN" >> "$ENV_FILE"
    printf "FULL_DOMAIN='%s'\n" "$FULL_DOMAIN" >> "$ENV_FILE"
    printf "FASTAPI_PORT='%s'\n" "$FASTAPI_PORT" >> "$ENV_FILE"
    printf "SERVER_USER='%s'\n" "$SERVER_USER" >> "$ENV_FILE"
    printf "SERVER_IP='%s'\n" "$SERVER_IP" >> "$ENV_FILE"
    printf "GITHUB_USER='%s'\n" "$GITHUB_USER" >> "$ENV_FILE"
    printf "BACKEND_REPO='%s'\n" "$BACKEND_REPO" >> "$ENV_FILE"
    printf "FRONTEND_REPO='%s'\n" "$FRONTEND_REPO" >> "$ENV_FILE"

    echo "✅ Archivo .env creado en $(pwd). 📂 Revísalo antes de continuar."
else
    printf "✅ .env ya existe, usaremos sus valores.\n"
fi

# 🚀 Cargar configuración desde .env (método seguro)
echo "📂 Cargando configuración desde $(pwd)/.env..."
set -o allexport
source "$ENV_FILE"
set +o allexport

# 🔍 Validar que todas las variables están definidas
for var in "${REQUIRED_VARS[@]}"; do
    if [[ -z "${!var}" ]]; then
        echo "❌ ERROR: La variable $var no está definida en el .env"
        exit 1
    fi
done

echo "✅ Todas las variables del .env fueron cargadas correctamente."

PROJECT_PATH="/opt/easyengine/sites/$FULL_DOMAIN/app/backend"
NGINX_CONFIG="/opt/easyengine/sites/$FULL_DOMAIN/config/nginx/custom/user.conf"
SSL_CERT="/etc/letsencrypt/live/$SITE_DOMAIN/fullchain.pem"
SSL_KEY="/etc/letsencrypt/live/$SITE_DOMAIN/privkey.pem"

# 🔐 Verificar certificados SSL
if [[ ! -f "$SSL_CERT" || ! -f "$SSL_KEY" ]]; then
    echo "❌ ERROR: No se encontraron los certificados SSL en:"
    echo "🔹 Certificado: $SSL_CERT"
    echo "🔹 Llave privada: $SSL_KEY"
    exit 1
fi

# 🌐 Verificar si el sitio existe en EasyEngine
if ee site list | grep -q "$FULL_DOMAIN"; then
    echo "⚠️ El sitio $FULL_DOMAIN ya existe en EasyEngine."
    read -p "🔄 ¿Quieres eliminarlo y recrearlo? (s/n): " RECREATE_SITE
    RECREATE_SITE=${RECREATE_SITE:-s}  # 🔹 Valor por defecto "s"
    if [[ "$RECREATE_SITE" == "s" ]]; then
        echo "🗑️ Eliminando sitio $FULL_DOMAIN..."
        if ee site delete "$FULL_DOMAIN" --yes; then
            echo "✅ Sitio eliminado correctamente."
        else
            echo "⚠️ El sitio no existía o hubo un error en la eliminación. Intentando limpieza manual..."
            rm -rf "/opt/easyengine/sites/$FULL_DOMAIN"
        fi
        echo "🚀 Creando sitio nuevamente..."
        ee site create "$FULL_DOMAIN" --ssl=custom --ssl-crt="$SSL_CERT" --ssl-key="$SSL_KEY"
    else
        echo "✅ Usando sitio existente en EasyEngine."
    fi
else
    echo "🚀 Creando sitio con EasyEngine..."
    ee site create "$FULL_DOMAIN" --ssl=custom --ssl-crt="$SSL_CERT" --ssl-key="$SSL_KEY"
fi

# 🏗️ Creación de estructura de proyecto
mkdir -p "$PROJECT_PATH"
cd "$PROJECT_PATH" || exit
echo "📂 Ubicación del proyecto: $(pwd)"

# 📦 Función para crear archivos si no existen o reemplazarlos
create_file_if_not_exists() {
    local file_path="$1"
    local content="$2"

    if [[ -f "$file_path" ]]; then
        read -p "⚠️ El archivo $file_path ya existe. ¿Quieres reemplazarlo? (s/n): " RECREATE_FILE
        RECREATE_FILE=${RECREATE_FILE:-s}
        if [[ "$RECREATE_FILE" != "s" ]]; then
            echo "✅ Conservando archivo existente: $file_path"
            return
        fi
        echo "🗑️ Eliminando $file_path..."
        rm "$file_path"
    fi

    echo "📄 Creando $file_path en $(pwd)..."

    if [[ -n "$content" ]]; then
        echo "$content" > "$file_path"
    else
        cat > "$file_path"
    fi
}

# 📜 Crear archivos con contenido seguro
create_file_if_not_exists "requirements.txt" "fastapi
uvicorn
sqlalchemy
psycopg2-binary
python-dotenv
pydantic
alembic
gunicorn
passlib[bcrypt]
email-validator"

create_file_if_not_exists "Dockerfile" <<EOF
FROM python:3.11
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "$FASTAPI_PORT"]
EOF

create_file_if_not_exists "docker-compose.yml" <<EOF
version: "3.8"

services:
  api:
    build: .
    container_name: showroom-api
    restart: always
    depends_on:
      - postgres
    networks:
      - showroom-network
    ports:
      - "8000:8000"
    environment:
      - DATABASE_URL='${DATABASE_URL}'  # 🔒 No se expande en Bash, Docker lo usará intacto
    volumes:
      - .:/app
    env_file:
      - .env  # Carga las variables desde .env

  postgres:
    image: postgres:16
    container_name: showroom-db
    restart: always
    networks:
      - showroom-network
    environment:
      - POSTGRES_USER='${DB_USER}'  # 🔒 Se mantiene sin expandirse
      - POSTGRES_PASSWORD='${DB_PASS}'
      - POSTGRES_DB='${DB_NAME}'
    volumes:
      - pgdata:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    env_file:
      - .env  # Carga las variables desde .env

networks:
  showroom-network:
    driver: bridge

volumes:
  pgdata:
EOF

# 📦 Crear archivo .env con las variables ya definidas
create_file_if_not_exists ".env" <<EOF
DB_USER="$DB_USER"
DB_PASS="$DB_PASS"
DB_NAME="$DB_NAME"
DB_HOST="showroom-db"
DB_PORT="5432"
DATABASE_URL="postgresql://$DB_USER:$DB_PASS@$DB_HOST:$DB_PORT/$DB_NAME"
EOF

# 📦 Crear .gitignore para evitar subir archivos sensibles
create_file_if_not_exists ".gitignore" <<EOF
.env
__pycache__/
*.pyc
*.pyo
venv/
EOF

echo "✅ Archivos del proyecto creados exitosamente."

# 🔄 Recargar Nginx con EasyEngine
echo "🔄 Recargando Nginx con EasyEngine..."
ee site reload "$FULL_DOMAIN"

DOCKER_SUBNET=$(docker network inspect bridge | grep -oP '(?<="Subnet": ")[^"]+')

echo "🔍 Eliminando reglas previas de UFW en el puerto $FASTAPI_PORT..."
ufw status numbered | awk '/'"$FASTAPI_PORT"'/ {print $1}' | sed 's/[^0-9]*//g' | sort -nr | while read -r rule_number; do
    if [[ -n "$rule_number" ]]; then
        echo "🗑️ Eliminando regla UFW número $rule_number..."
        ufw --force delete "$rule_number"
    fi
done

echo "🚫 Bloqueando acceso público al puerto $FASTAPI_PORT..."
ufw deny to any port "$FASTAPI_PORT" proto tcp

echo "🔐 Permitiendo acceso solo desde la red interna de Docker: $DOCKER_SUBNET"
ufw allow from "$DOCKER_SUBNET" to any port "$FASTAPI_PORT" proto tcp

ufw reload

echo "🎉 Setup completado."
echo "👉 Ahora ejecuta: cd $PROJECT_PATH && docker-compose up -d"

cd "$PROJECT_PATH"
if [[ -f "main.py" ]]; then
    echo "🗑️ Eliminando main.py existente..."
    rm "main.py"
fi

create_file_if_not_exists "main.py" <<EOF
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

app = FastAPI()

# 🔹 Habilitar CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://$FULL_DOMAIN"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 🔹 Ruta raíz
@app.get("/", response_class=JSONResponse)
def read_root():
    return JSONResponse(content={"message": "🚀 FastAPI con SSL lista"}, media_type="application/json")
EOF

# 🚀 Forzar reconstrucción de la imagen sin caché
echo "📦 Construyendo imagen de Docker sin caché..."
docker-compose build --no-cache

# 📦 Asegurar que las imágenes base están actualizadas
echo "📦 Verificando imágenes base..."
docker pull python:3.11
docker pull postgres:16

# 🚀 Levantar la API con Docker
echo "🚀 Levantando la API con Docker..."
docker-compose up -d
