# 🚀 Deploying GramSetu on Render

GramSetu 2.0 is fully configured for deployment on [Render](https://render.com). It can be deployed in under 2 minutes using either **Render Blueprints (automatic)** or by creating a **Web Service**.

---

## ⚡ Method 1: 1-Click Blueprint Deployment (Recommended)

1. Log into your [Render Dashboard](https://dashboard.render.com).
2. Click the **"New +"** button in the top navigation bar.
3. Select **"Blueprint"**.
4. Connect your GitHub account and choose your repository:
   - **Repository**: `mahalakshmidrv/GramSetu`
   - **Branch**: `main`
5. Render will automatically detect the `render.yaml` configuration file and pre-populate:
   - **Service Name**: `gramsetu`
   - **Runtime**: `Python 3.11.9`
   - **Build Command**: `pip install -r requirements.txt`
   - **Start Command**: `uvicorn backend.main:app --host 0.0.0.0 --port $PORT --proxy-headers`
   - **CORS Configuration**: `GRAMSETU_CORS_ORIGINS=*`
6. Click **"Apply"**.
7. Render will build and deploy your application. Within 1–2 minutes, your live URL will be active (e.g., `https://gramsetu.onrender.com`).

---

## 🛠️ Method 2: Manual Web Service Setup

If you prefer configuring the Web Service manually:

1. In Render Dashboard, click **"New +"** → **"Web Service"**.
2. Connect your repository: `https://github.com/mahalakshmidrv/GramSetu`.
3. Configure the following fields:
   - **Name**: `gramsetu` (or any custom name)
   - **Region**: Choose the closest region (e.g., *Singapore* or *Oregon*)
   - **Branch**: `main`
   - **Root Directory**: Leave blank (uses repository root)
   - **Runtime**: `Python 3`
   - **Build Command**:
     ```bash
     pip install -r requirements.txt
     ```
   - **Start Command**:
     ```bash
     uvicorn backend.main:app --host 0.0.0.0 --port $PORT --proxy-headers
     ```
   - **Instance Type**: `Free`
4. Under **"Environment Variables"**, add:
   | Key | Value | Description |
   |---|---|---|
   | `PYTHON_VERSION` | `3.11.9` | Sets the Python version |
   | `GRAMSETU_CORS_ORIGINS` | `*` | Allows mobile & web clients to connect |
5. Click **"Create Web Service"**.

---

## 🌐 What Goes Live

Once deployed on Render, your web service provides:
1. **PWA Frontend**: Access the full GramSetu web app directly at your Render domain: `https://<your-service-name>.onrender.com`.
2. **REST API**: Accessible under `/api/...` (e.g. `https://<your-service-name>.onrender.com/api/health`).
3. **Swagger API Docs**: Interactive API documentation at `https://<your-service-name>.onrender.com/docs`.
4. **Mobile App Backend**: In the GramSetu Flutter app under **Sync & Settings**, set the Server Base URL to your Render domain (`https://<your-service-name>.onrender.com`) to sync offline messages, SOS alerts, and village resources globally!
