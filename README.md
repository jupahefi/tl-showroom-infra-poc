
# 📌 TL Showroom Infra PoC

Este repositorio contiene scripts automatizados para la instalación y despliegue de una aplicación web fullstack utilizando **EasyEngine**, **Docker Compose**, **FastAPI**, **PostgreSQL**, **Vue 3 + Vite** y **GitHub Actions**.

## ✅ Requisitos Previos

Antes de ejecutar cualquier script, asegúrate de:

1. 🧰 Tener instalado [**EasyEngine**](https://easyengine.io/)
2. 🔐 Contar con **certificados SSL válidos** previamente generados para tu dominio
3. 🧬 Clonar este repositorio en tu servidor:

```bash
git clone https://github.com/jupahefi/tl-showroom-infra-poc.git
cd tl-showroom-infra-poc
```

---

## 🚀 Tecnologías Utilizadas

- **EasyEngine**: Administra el frontend con **Nginx autoadministrado**
- **Docker Compose**: Orquesta el backend con **FastAPI** y **PostgreSQL**
- **Vue 3 + Vite**: Framework frontend desplegado mediante EasyEngine
- **GitHub CLI + GitHub Actions**: Automatización de repositorios y despliegues

---

## 🛠️ Instalación Paso a Paso

### 1️⃣ Configuración del Entorno
```bash
bash environment-init.sh
```
Instala dependencias (excepto EasyEngine), inicializa variables, configura el backend y prepara certificados SSL y la base de datos PostgreSQL (aislada).

### 2️⃣ Instalación del Frontend
```bash
bash frontend-init.sh
```
Construye el frontend con Vue 3 + Vite y lo despliega en el sitio gestionado por EasyEngine.

### 3️⃣ Creación de Repositorios en GitHub
```bash
bash fullstack-repos-init.sh
```
Crea los repositorios para frontend y backend usando **GitHub CLI** y realiza el primer commit.

### 4️⃣ Configuración de GitHub Actions
```bash
bash gh-fullstack-actions-init.sh
```
Inicializa workflows de CI/CD en ambos repos utilizando **GitHub CLI**.

---

## 🔗 Arquitectura del Proyecto

1. **Backend:**
   - FastAPI + PostgreSQL en Docker Compose
   - Base de datos segura (solo accesible internamente)
   - Conexión con Nginx mediante **proxy_pass**

2. **Frontend:**
   - Vue 3 + Vite
   - Servido con EasyEngine (integrado con Nginx)
   - Conexión HTTPS al backend a través de EasyEngine

3. **CI/CD:**
   - GitHub Actions para despliegue automático

---

## 🎯 Notas Importantes

- **Este script está diseñado exclusivamente para entornos con EasyEngine**
- **El certificado SSL debe existir en la ruta del sitio**
- **Requiere acceso a GitHub CLI para la creación de repositorios**
- **Los contenedores de Docker deben estar en la misma red que EasyEngine para funcionar correctamente**

🔹 Con esta infraestructura, logras un **despliegue automatizado** de tu aplicación web. 🚀
