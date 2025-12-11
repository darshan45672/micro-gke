# Micro Frontend Demo with Kubernetes

A demonstration of micro frontend architecture using Next.js and Vue.js, deployed on Kubernetes.

## 🎯 Quick Deploy Guide

**Complete deployment in 3 steps:**

```bash
# 1. Build and deploy to Kubernetes
./build-and-deploy.sh

# 2. Set up port forwarding (Kind only)
./start-port-forward.sh

# 3. Open in browser
# Next.js: http://localhost:30001
# Vue.js: http://localhost:30002
```

That's it! Your micro frontends are running on Kubernetes. 🚀

---

## 🏗️ Architecture

This project demonstrates micro frontends with two independent applications:

- **mf1** (Next.js 16.0.8) - Landing page with navigation to the blog
- **mf2** (Vue.js 3.5.25 + PrimeVue) - Blog listing page with PrimeVue components

```
┌─────────────────────────────────────────────┐
│         Micro Frontend Architecture         │
│                                             │
│  ┌─────────────────┐      ┌──────────────┐ │
│  │   Next.js App   │ ───▶ │  Vue.js App  │ │
│  │   (Landing)     │      │   (Blogs)    │ │
│  │   Port: 3000    │      │   Port: 5173 │ │
│  └─────────────────┘      └──────────────┘ │
│           │                       │         │
│           └───────────┬───────────┘         │
│                       │                     │
│              Kubernetes Cluster            │
│         NodePort: 30001  NodePort: 30002   │
└─────────────────────────────────────────────┘
```

## 📁 Project Structure

```
micro-gke/
├── mf1/                    # Next.js landing page
│   ├── app/
│   │   └── page.tsx       # Landing page component
│   ├── Dockerfile
│   └── package.json
├── mf2/                    # Vue.js blog listing
│   ├── src/
│   │   ├── App.vue        # Blog listing with PrimeVue
│   │   └── main.ts
│   ├── Dockerfile
│   ├── nginx.conf
│   └── package.json
├── k8s/                    # Kubernetes manifests
│   ├── mf1-deployment.yaml
│   ├── mf2-deployment.yaml
│   └── ingress.yaml
├── build-and-deploy.sh     # Automated deployment script
├── update-urls.sh          # Update app URLs for k8s
└── README-k8s.md          # Detailed k8s guide
```

## 🚀 Quick Start

### Development Mode

**mf1 (Next.js):**
```bash
cd mf1
npm install
npm run dev
# Access at http://localhost:3000
```

**mf2 (Vue.js):**
```bash
cd mf2
npm install
npm run dev
# Access at http://localhost:5173
```

### Kubernetes Deployment

**Prerequisites:**
- Kubernetes cluster (Minikube, Docker Desktop, Kind, or K3s)
- kubectl CLI
- Podman or Docker

#### Step 1: Build and Deploy to Kubernetes

```bash
# Make the script executable (first time only)
chmod +x build-and-deploy.sh

# Build Docker images and deploy to Kubernetes
./build-and-deploy.sh
```

This will:
1. Build Docker images for both apps with production environment variables
2. Load images into your cluster (Kind or Minikube)
3. Deploy to Kubernetes with NodePort services
4. Display access URLs

#### Step 2: Set Up Port Forwarding (Required for Kind)

If you're using **Kind**, NodePort services are not directly accessible. You need port forwarding:

```bash
# Make the script executable (first time only)
chmod +x start-port-forward.sh

# Start port forwarding
./start-port-forward.sh
```

This forwards:
- `localhost:30001` → Next.js Landing Page
- `localhost:30002` → Vue.js Blog Listing

**Note:** For Minikube or cloud Kubernetes (GKE, EKS, AKS), NodePort services work directly without port forwarding.

#### Step 3: Access Your Applications

Open your browser:
- **Next.js Landing Page**: http://localhost:30001
- **Vue.js Blog Listing**: http://localhost:30002

Click "View Blogs →" to navigate between micro frontends!

#### Common Operations

```bash
# Stop port forwarding (Kind only)
./stop-port-forward.sh

# Check deployment status
kubectl get pods
kubectl get svc

# View application logs
kubectl logs -l app=mf1-nextjs
kubectl logs -l app=mf2-vuejs

# Restart deployments after code changes
./build-and-deploy.sh
./start-port-forward.sh  # Kind only

# Delete all resources
kubectl delete -f k8s/
```

**For detailed manual steps:** See [README-k8s.md](./README-k8s.md)  
**For quick reference:** See [QUICKSTART.md](./QUICKSTART.md)

## 🔧 Configuration

### Environment Variables

Applications use environment variables for cross-navigation:

**mf1/.env.production (Next.js):**
```env
NEXT_PUBLIC_BLOG_URL=http://localhost:30002
```

**mf2/.env.production (Vue.js):**
```env
VITE_LANDING_URL=http://localhost:30001
```

These files are automatically used during Docker builds to configure the correct URLs for Kubernetes deployment.

**Runtime Configuration:**
- **mf1 (Next.js):** Port 3000, standalone server
- **mf2 (Vue.js):** Port 80, served via nginx

### Kubernetes Resources

**NodePort Services:**
- mf1-nextjs-service: Port 3000 → NodePort 30001
- mf2-vuejs-service: Port 80 → NodePort 30002

**Deployments:**
- 2 replicas per application
- Resource limits configured
- Health checks (liveness + readiness probes)
- Rolling update strategy

## 📦 Technologies

### mf1 (Landing Page)
- **Framework:** Next.js 16.0.8
- **React:** 19.1.0
- **TypeScript:** 5.x
- **Styling:** CSS Modules
- **Build:** Standalone output

### mf2 (Blog Listing)
- **Framework:** Vue.js 3.5.25
- **UI Library:** PrimeVue 4.5.3
- **Icons:** PrimeIcons 7.0.0
- **TypeScript:** 5.9.x
- **Build:** Vite 7.2.4
- **Server:** Nginx (Alpine)

## 🎨 Features

### Landing Page (mf1)
- Modern gradient design
- Responsive layout
- "View Blogs" CTA button
- Micro frontend explanation card
- Direct navigation to Vue.js app

### Blog Listing (mf2)
- PrimeVue component library
- 5 static blog posts
- Professional card design
- Category badges with severity colors
- Author avatars
- Tag system
- Stats section
- "Back to Landing Page" button
- Fully responsive design

## 📊 Kubernetes Resources

## 🔍 Troubleshooting

### Applications Not Loading?

**For Kind Clusters:**
```bash
# Check if port forwarding is running
jobs

# Restart port forwarding
./stop-port-forward.sh
./start-port-forward.sh
```

**For All Clusters:**
```bash
# Check pod status
kubectl get pods

# View pod logs
kubectl logs -l app=mf1-nextjs
kubectl logs -l app=mf2-vuejs

# Check events
kubectl get events --sort-by='.lastTimestamp' | tail -20

# Describe pod for details
kubectl describe pod <pod-name>
```

### Pods Not Starting?

```bash
# Check if images are loaded (Kind)
podman exec -it micro-gke-control-plane crictl images

# Force rebuild and redeploy
./build-and-deploy.sh

# Check pod details
kubectl describe deployment mf1-nextjs
kubectl describe deployment mf2-vuejs
```

### Navigation Between Apps Not Working?

The apps should already be configured with correct URLs. If navigation fails:

1. Verify environment files exist:
   ```bash
   cat mf1/.env.production  # Should show NEXT_PUBLIC_BLOG_URL=http://localhost:30002
   cat mf2/.env.production  # Should show VITE_LANDING_URL=http://localhost:30001
   ```

2. Rebuild images to pick up environment variables:
   ```bash
   ./build-and-deploy.sh
   ```

3. Restart port forwarding (Kind only):
   ```bash
   ./start-port-forward.sh
   ```

## 📊 Monitoring

```bash
# Watch pod status in real-time
kubectl get pods -w

# Stream logs from all replicas
kubectl logs -f -l app=mf1-nextjs
kubectl logs -f -l app=mf2-vuejs

# Check resource usage
kubectl top pods

# View service endpoints
kubectl get endpoints

# Scale deployments
kubectl scale deployment mf1-nextjs --replicas=3
kubectl scale deployment mf2-vuejs --replicas=3
```

## 🧹 Cleanup

```bash
# Delete all resources
kubectl delete -f k8s/mf1-deployment.yaml
kubectl delete -f k8s/mf2-deployment.yaml
kubectl delete -f k8s/ingress.yaml

# Or delete by label
kubectl delete all -l tier=frontend
```

## 📖 Documentation

- [Kubernetes Deployment Guide](./README-k8s.md) - Detailed deployment instructions
- [mf1 README](./mf1/README.md) - Next.js app documentation
- [mf2 README](./mf2/README.md) - Vue.js app documentation

## 🤝 Contributing

This is a demonstration project. Feel free to fork and modify for your own micro frontend experiments.

## 📝 License

MIT

## ✅ Deployment Checklist

Use this checklist when deploying to Kubernetes:

### First-Time Setup
- [ ] Kubernetes cluster running (Kind, Minikube, or cloud)
- [ ] `kubectl` configured and connected to cluster
- [ ] Podman or Docker installed
- [ ] Scripts made executable: `chmod +x *.sh`

### Every Deployment
- [ ] Run `./build-and-deploy.sh`
- [ ] Wait for "Deployment Complete!" message
- [ ] **For Kind only**: Run `./start-port-forward.sh`
- [ ] Verify pods running: `kubectl get pods`
- [ ] Test Next.js: http://localhost:30001
- [ ] Test Vue.js: http://localhost:30002
- [ ] Test navigation: Click "View Blogs →" button
- [ ] Test back navigation: Click "Back to Landing Page"

### After Code Changes
- [ ] Stop port forwarding: `./stop-port-forward.sh` (Kind only)
- [ ] Rebuild: `./build-and-deploy.sh`
- [ ] Restart port forwarding: `./start-port-forward.sh` (Kind only)
- [ ] Test both applications

### Cleanup
- [ ] Stop port forwarding: `./stop-port-forward.sh`
- [ ] Delete resources: `kubectl delete -f k8s/`
- [ ] Optional: Delete cluster: `kind delete cluster --name micro-gke`

## 🎯 Key Concepts Demonstrated

1. **Micro Frontend Architecture** - Independent apps working together
2. **Technology Diversity** - Next.js + Vue.js in one solution
3. **Kubernetes Deployment** - Production-ready container orchestration
4. **Environment-Based Configuration** - Build-time environment variables
5. **Health Monitoring** - Liveness and readiness probes
6. **Service Discovery** - Kubernetes services for inter-app communication
5. **Scaling** - Horizontal pod autoscaling ready
6. **Service Discovery** - Kubernetes services and NodePort
7. **Modern UI** - PrimeVue component library
8. **Build Optimization** - Multi-stage Docker builds
9. **Production Patterns** - Standalone Next.js, nginx for SPA

## 🔗 Access URLs

### Development
- Landing Page: http://localhost:3000
- Blog Listing: http://localhost:5173

### Kubernetes (Minikube)
- Landing Page: http://`<minikube-ip>`:30001
- Blog Listing: http://`<minikube-ip>`:30002

### Kubernetes (localhost)
- Landing Page: http://localhost:30001
- Blog Listing: http://localhost:30002
