<h1 align="center">E-Commerce Store 🛒</h1>

![Demo App](/frontend/public/screenshot-for-readme.png)

[Video Tutorial on Youtube](https://youtu.be/sX57TLIPNx8)

About This Course:

-   🚀 Project Setup
-   🗄️ MongoDB & Redis Integration
-   💳 Stripe Payment Setup
-   🔐 Robust Authentication System
-   🔑 JWT with Refresh/Access Tokens
-   📝 User Signup & Login
-   🛒 E-Commerce Core
-   📦 Product & Category Management
-   🛍️ Shopping Cart Functionality
-   💰 Checkout with Stripe
-   🏷️ Coupon Code System
-   👑 Admin Dashboard
-   📊 Sales Analytics
-   🎨 Design with Tailwind
-   🛒 Cart & Checkout Process
-   🔒 Security
-   🛡️ Data Protection
-   🚀Caching with Redis
-   ⌛ And a lot more...

### Setup .env file

```bash
PORT=5000
MONGO_URI=your_mongo_uri

UPSTASH_REDIS_URL=your_redis_url

ACCESS_TOKEN_SECRET=your_access_token_secret
REFRESH_TOKEN_SECRET=your_refresh_token_secret

CLOUDINARY_CLOUD_NAME=your_cloud_name
CLOUDINARY_API_KEY=your_api_key
CLOUDINARY_API_SECRET=your_api_secret

STRIPE_SECRET_KEY=your_stripe_secret_key
CLIENT_URL=http://localhost:5173
NODE_ENV=development
```

### Run this app locally

```shell
npm run build
```

### Start the app

```shell
npm run start
```

<h1 align="center">🛒 MERN E-Commerce Store — CI/CD Pipeline</h1>

<p align="center">
A full-stack MERN e-commerce application with an automated CI/CD pipeline that lints, scans, and builds container images on every push to <code>main</code>.
</p>

![Demo App](/frontend/public/screenshot-for-readme.png)

---

## 🌳 Repository Branches

This project is split across three branches, each responsible for one part of the stack:

| Branch | Purpose |
|---|---|
| **`main`** *(this branch)* | Frontend + backend application source code, plus the GitHub Actions CI/CD pipeline |
| **[`k8s`](../../tree/k8s)** | Helm chart (`mern-ecommerce`) with Kubernetes manifests, and a bash script to install the AWS Load Balancer Controller on the EKS cluster |
| **[`terraform`](../../tree/terraform)** | Infrastructure as Code — `terraform-vpc` (builds the AWS VPC) and `terraform-eks` (provisions the EKS cluster inside that VPC) |

**Typical flow:** `terraform` branch stands up the VPC + EKS cluster → `k8s` branch deploys the app onto that cluster via Helm → `main` branch's pipeline builds and pushes the Docker images those manifests deploy.

---

## 📦 What's in this branch (`main`)

```
.
├── .github/workflows/ci-cd.yml   # CI/CD pipeline definition
├── backend/                      # Express + MongoDB API
│   ├── controllers/              # auth, cart, coupon, payment, product, analytics
│   ├── models/                   # Mongoose schemas
│   ├── routes/
│   ├── lib/                      # db, redis, cloudinary, stripe clients
│   ├── middleware/
│   ├── Dockerfile
│   └── server.js
├── frontend/                     # React (Vite) client
│   ├── src/
│   ├── Dockerfile
│   └── ...
├── package.json                  # Root scripts (backend deps live at root)
├── sonar-project.properties      # SonarCloud config
└── .env.example
```

> **Note:** The backend's dependencies live in the **root** `package.json`, not inside `backend/` — the backend Dockerfile's build context is the repo root for this reason.

---

## ✨ Application Features

- 🔐 JWT authentication with access/refresh tokens
- 🛍️ Product & category management
- 🛒 Shopping cart
- 🏷️ Coupon code system
- 💳 Stripe checkout
- 👑 Admin dashboard with sales analytics
- 🚀 Redis caching (Upstash)
- ☁️ Cloudinary image storage
- 🎨 Tailwind CSS UI

**Stack:** React 18 + Vite + Zustand + Tailwind (frontend) · Node.js + Express + MongoDB (Mongoose) + Redis (frontend/backend)

---

## 🔄 CI/CD Pipeline (`.github/workflows/ci-cd.yml`)

Triggered on every push to `main` (and manually via `workflow_dispatch`). Three sequential jobs:

1. **Unit Tests & Lint**
   - Installs backend and frontend dependencies (Node 22)
   - Runs frontend ESLint (`npm run lint`)
   - *(Backend currently has no test script — this step is a placeholder for future tests)*

2. **SonarCloud Analysis** *(runs after tests pass)*
   - Static code analysis of `backend/` and `frontend/src/`
   - Configured via `sonar-project.properties`

3. **Build & Push Docker Images** *(runs after tests + Sonar pass)*
   - Builds and pushes two images to Docker Hub, tagged `latest` and `v<run_number>`:
     - `vipulsingh2200/mern-ecommerce-backend`
     - `vipulsingh2200/mern-ecommerce-frontend`
   - These are the images referenced by the Helm chart in the [`k8s`](../../tree/k8s) branch

**Required GitHub Secrets:** `SONAR_TOKEN`, `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`

---

## ⚙️ Environment Variables

Create a `.env` file in the repo root (see `.env.example`):

```env
PORT=5000
MONGO_URI=your_mongo_uri
UPSTASH_REDIS_URL=your_redis_url
ACCESS_TOKEN_SECRET=your_access_token_secret
REFRESH_TOKEN_SECRET=your_refresh_token_secret
CLOUDINARY_CLOUD_NAME=your_cloud_name
CLOUDINARY_API_KEY=your_api_key
CLOUDINARY_API_SECRET=your_api_secret
STRIPE_SECRET_KEY=your_stripe_secret_key
CLIENT_URL=http://localhost:5173
NODE_ENV=development
```

---

## 🚀 Running Locally

```bash
# Install deps + build frontend
npm run build

# Start the server (serves API + built frontend)
npm run start
```

For active development with hot reload:

```bash
npm run dev              # backend, via nodemon
cd frontend && npm run dev   # frontend, via Vite
```

---

## 🐳 Running with Docker

```bash
# Backend (build context = repo root)
docker build -t mern-backend -f backend/Dockerfile .
docker run -p 5000:5000 --env-file .env mern-backend

# Frontend (build context = ./frontend)
docker build -t mern-frontend ./frontend
docker run -p 80:80 mern-frontend
```

> The frontend image calls the backend via a relative `/api` path in production — your reverse proxy / ingress needs to route `/api` to the backend service. This is exactly what the Helm chart in the `k8s` branch sets up.

---

## ☸️ Deploying to Kubernetes

See the [`k8s`](../../tree/k8s) branch for the Helm chart and EKS setup instructions, and the [`terraform`](../../tree/terraform) branch for provisioning the underlying AWS VPC and EKS cluster.
