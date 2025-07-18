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

# 📌 Variables de entorno del frontend
FRONTEND_DIR="/opt/frontend"
PROJECT_NAME="showroom-frontend"
DOMAIN="$FULL_DOMAIN"
SSL_CERT="/etc/letsencrypt/live/$SITE_DOMAIN/fullchain.pem"
SSL_KEY="/etc/letsencrypt/live/$SITE_DOMAIN/privkey.pem"

# 📜 Función para crear o reemplazar archivos
create_or_replace_file() {
    local file_path="$1"
    local content="$2"

    if [[ -f "$file_path" ]]; then
        echo "🗑️ Eliminando archivo existente: $file_path"
        rm "$file_path"
    fi

    echo "📄 Creando archivo: $file_path"
    echo "$content" > "$file_path"
}

# 🛠️ Verificar si Node.js y npm están instalados
if ! command -v node &> /dev/null; then
    echo "🔹 Node.js no encontrado. Instalando..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt-get install -y nodejs
fi

# 🛠️ Instalar Vite y Vue globalmente
echo "📦 Instalando Vite y Vue..."
npm install -g create-vite

# 📂 Crear la carpeta del frontend si no existe
mkdir -p "$FRONTEND_DIR"
cd "$FRONTEND_DIR"

# 🗑️ Eliminar el proyecto existente si ya está creado
if [[ -d "$PROJECT_NAME" ]]; then
    echo "🗑️ Eliminando proyecto existente: $PROJECT_NAME"
    rm -rf "$PROJECT_NAME"
fi

# 🚀 Crear un nuevo proyecto con Vite y Vue 3 (TypeScript)
echo "🚀 Creando nuevo proyecto Vite + Vue 3 (TypeScript)..."
npm init vite@3 "$PROJECT_NAME" -- --template vue-ts --yes

# 📂 Entrar al proyecto y configurar dependencias
cd "$PROJECT_NAME"
echo "📦 Instalando dependencias..."
npm install
npm install axios vue-tsc

# 📜 Configurar TypeScript para Vue
create_or_replace_file "src/env.d.ts" \
'/// <reference types="vite/client" />
declare module "*.vue" {
    import { DefineComponent } from "vue";
    const component: DefineComponent<{}, {}, any>;
    export default component;
}'

# 📜 Configurar `vite.config.ts` para soportar Vue
create_or_replace_file "vite.config.ts" \
'import { defineConfig } from "vite";
import vue from "@vitejs/plugin-vue";

export default defineConfig({
    plugins: [vue()],
    server: {
        host: true,
        port: 5173,
        strictPort: true
    },
    build: {
        outDir: "dist"
    }
});'

# 📜 Crear un componente Vue que consume el backend
create_or_replace_file "src/components/BackendData.vue" \
'<script setup lang="ts">
import { ref, onMounted, computed } from "vue";
import axios from "axios";

interface ApiResponse {
    message?: string;
    error?: string;
}

const backendData = ref<ApiResponse | null>(null);
const reloadCount = ref(0);

const fetchData = async () => {
    try {
        const response = await axios.get<ApiResponse>("/api/");
        console.log("✅ Respuesta del backend:", response);
        backendData.value = response.data;
        reloadCount.value++;
    } catch (error: any) {
        console.error("❌ Error al conectar con el backend:", error);
        backendData.value = {
            error: error.response
                ? `Error ${error.response.status}: ${error.response.statusText}`
                : "El backend no responde.",
        };
    }
};

onMounted(() => {
    fetchData();
    setInterval(fetchData, 10000);
});

const formattedResponse = computed(() =>
    backendData.value ? JSON.stringify(backendData.value, null, 2) : "Cargando..."
);
</script>

<template>
    <div class="container">
        <!-- Respuesta de FastAPI -->
        <pre class="response">{{ formattedResponse }}</pre>

        <!-- Contador de recargas -->
        <p class="reload-counter">🔄 Backend recargado: {{ reloadCount }} veces</p>

        <!-- Logos con enlaces y neon glow -->
        <div class="logos">
            <a href="https://vuejs.org/" target="_blank"><div class="icon-box"><img src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/vuejs/vuejs-original.svg" alt="Vue.js" /></div></a>
            <a href="https://vitejs.dev/" target="_blank"><div class="icon-box"><img src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/vite/vite-original.svg" alt="Vite" /></div></a>
            <a href="https://fastapi.tiangolo.com/" target="_blank"><div class="icon-box"><img src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/fastapi/fastapi-original.svg" alt="FastAPI" /></div></a>
            <a href="https://www.python.org/" target="_blank"><div class="icon-box"><img src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/python/python-original.svg" alt="Python" /></div></a>
            <a href="https://www.javascript.com/" target="_blank"><div class="icon-box"><img src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/javascript/javascript-original.svg" alt="JavaScript" /></div></a>
            <a href="https://www.postgresql.org/" target="_blank"><div class="icon-box"><img src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/postgresql/postgresql-original.svg" alt="PostgreSQL" /></div></a>
            <a href="https://docs.docker.com/compose/" target="_blank"><div class="icon-box"><img src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/docker/docker-original.svg" alt="Docker Compose" /></div></a>
            <a href="https://nginx.org/" target="_blank"><div class="icon-box"><img src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/nginx/nginx-original.svg" alt="Nginx" /></div></a>
            <a href="https://www.gnu.org/software/bash/" target="_blank"><div class="icon-box"><img src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/bash/bash-original.svg" alt="Bash" /></div></a>
            <a href="https://github.com/features/actions" target="_blank"><div class="icon-box"><img src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/github/github-original.svg" alt="GitHub Actions" /></div></a>
            <a href="https://www.vultr.com/" target="_blank"><div class="icon-box"><img src="https://www.vultr.com/media/logo.svg" alt="Vultr" /></div></a>
            <a href="https://easyengine.io/" target="_blank"><div class="icon-box"><img src="https://avatars.githubusercontent.com/u/3853786?s=200&v=4" alt="EasyEngine" /></div></a>
        </div>
    </div>
</template>

<style scoped>
/* Contenedor principal */
.container {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    text-align: center;
    min-height: auto;
    background: rgba(20, 20, 20, 0.9); /* Más oscuro */
    backdrop-filter: blur(5px);
    color: white;
    font-family: Arial, sans-serif;
    padding: 20px;
    border-radius: 10px;
    border: 1px solid rgba(255, 255, 255, 0.15);
}

/* Respuesta API con efecto cristalizado */
.response {
    background: rgba(255, 255, 255, 0.1);
    backdrop-filter: blur(8px);
    padding: 15px;
    border-radius: 10px;
    font-size: 0.9rem;
    white-space: pre-wrap;
    word-wrap: break-word;
    max-width: 90%;
    overflow-x: auto;
    text-align: left;
    max-height: 200px;
    overflow-y: auto;
    border: 1px solid rgba(255, 255, 255, 0.2);
    margin-bottom: 10px;
}

/* Contador de recargas */
.reload-counter {
    font-size: 1.2rem;
    color: #ff9d00;
    margin: 10px 0 15px;
}

/* Logos con glow y bordes suaves */
.logos {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(70px, 1fr));
    gap: 20px;
    width: 100%;
    max-width: 800px;
    margin-top: 10px;
    justify-content: center; /* Centra la última fila */
    grid-auto-flow: row dense; /* Evita espacios vacíos */
}

/* Máximo 5 iconos por fila en PC */
@media (min-width: 768px) {
    .logos {
        grid-template-columns: repeat(5, 1fr);
        justify-content: center; /* Asegura que la última fila se centre */
    }
}

.icon-box {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 70px;
    height: 70px;
    border-radius: 15px;
    background-color: white;
    padding: 5px;
    transition: transform 0.3s ease-in-out, filter 0.3s ease-in-out;
    filter: drop-shadow(0px 0px 5px rgba(255, 255, 255, 0.6));
}

/* Neon Glow alrededor */
.icon-box:hover {
    filter: drop-shadow(0px 0px 10px rgba(255, 0, 255, 0.8)) drop-shadow(0px 0px 15px rgba(255, 165, 0, 0.8));
    transform: scale(1.1);
}

.icon-box img {
    width: 50px;
    height: auto;
}

/* Ajustes responsivos */
@media (max-width: 600px) {
    .container {
        padding: 10px;
    }

    .logos {
        max-width: 90%;
        gap: 4vw;
    }

    .icon-box {
        width: 60px;
        height: 60px;
    }

    .icon-box img {
        width: 45px;
    }

    .response {
        font-size: 0.85rem;
    }

    .reload-counter {
        font-size: 1rem;
    }
}
</style>'

# 📜 Modificar App.vue para mostrar el mensaje y la respuesta del backend
create_or_replace_file "src/App.vue" \
'<script setup lang="ts">
import BackendData from "./components/BackendData.vue";
</script>

<template>
    <div class="app-wrapper">
        <!-- Título con glow y emoji WebP -->
        <h1 class="glow-title">
            <img src="https://em-content.zobj.net/source/telegram/386/rocket_1f680.webp"
                alt="🚀" class="emoji" />
            Vite+Vue y FastAPI con HTTPS
        </h1>

        <!-- Componente que maneja la conexión con el backend -->
        <BackendData />
    </div>
</template>

<style scoped>
/* Envoltorio principal */
.app-wrapper {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: flex-start; /* Asegura que el contenido empiece arriba */
    text-align: center;
    min-height: 100vh;
    padding-top: 0; /* 🔥 Eliminamos el padding extra */
}

/* Glow aplicado al título */
.glow-title {
    font-size: clamp(2.5rem, 5vw, 4rem);
    color: white;
    text-shadow: 0 0 8px #ff9d00, 0 0 15px #ff4e00, 0 0 20px #e100ff;
    animation: neonGlow 1.5s infinite alternate ease-in-out;
    font-weight: bold;
    padding: 5px 0; /* 🔥 Reducimos el padding vertical */
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 5px; /* 🔥 Menos espacio entre emoji y texto */
}

/* Imagen del emoji WebP */
.emoji {
    width: clamp(40px, 4vw, 50px);
    height: auto;
    display: inline-block;
}

/* Animación Neon */
@keyframes neonGlow {
    0% { text-shadow: 0 0 8px #ff9d00, 0 0 15px #ff4e00, 0 0 20px #e100ff; }
    50% { text-shadow: 0 0 12px #ff4e00, 0 0 22px #e100ff, 0 0 28px #ff9d00; }
    100% { text-shadow: 0 0 8px #e100ff, 0 0 15px #ff9d00, 0 0 20px #ff4e00; }
}

/* Ajustes responsivos */
@media (max-width: 600px) {
    .glow-title {
        font-size: clamp(2rem, 6vw, 3rem);
    }
    .emoji {
        width: clamp(30px, 5vw, 40px);
    }
}
</style>'

# 📦 Construir la aplicación
echo "🏗️ Construyendo frontend..."
npm run build

# 📂 Mover archivos estáticos correctamente
echo "📂 Moviendo archivos estáticos a /htdocs..."
rsync -av --delete /opt/frontend/showroom-frontend/dist/ /opt/easyengine/sites/$DOMAIN/app/htdocs/

# 📄 Configurar Nginx con el backend correcto
create_or_replace_file "/opt/easyengine/sites/$DOMAIN/config/nginx/custom/user.conf" \
"location /api/ {
    proxy_pass http://showroom-api:8000/;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
}"

# 🔄 Recargar Nginx con EasyEngine
echo "🔄 Recargando Nginx con EasyEngine..."
docker network connect ee-global-frontend-network showroom-api
ee site reload "$DOMAIN"

echo "🎉 Frontend desplegado con éxito."
echo "👉 Accede en: https://$DOMAIN"