# Quick Reference - Micro Frontend Demo

## 🚀 Access the Applications

- **Next.js Landing Page**: http://localhost:30001
- **Vue.js Blog Listing**: http://localhost:30002

## 📋 Common Commands

### Port Forwarding (Required for Kind clusters)
```bash
# Start port forwarding
./start-port-forward.sh

# Stop port forwarding
./stop-port-forward.sh

# Check if port forwarding is running
jobs
```

### Kubernetes Operations
```bash
# Check pod status
kubectl get pods

# Check services
kubectl get svc

# View pod logs
kubectl logs -l app=mf1-nextjs
kubectl logs -l app=mf2-vuejs

# Restart deployments
kubectl rollout restart deployment/mf1-nextjs
kubectl rollout restart deployment/mf2-vuejs

# Delete deployments
kubectl delete -f k8s/
```

### Rebuild and Redeploy
```bash
# Full rebuild and deploy
./build-and-deploy.sh

# Then restart port forwarding (Kind only)
./start-port-forward.sh
```

## 🔍 Troubleshooting

### Applications not accessible?
1. Check if port forwarding is running: `jobs`
2. Check pod status: `kubectl get pods`
3. Check pod logs: `kubectl logs -l app=mf1-nextjs`
4. Restart port forwarding: `./stop-port-forward.sh && ./start-port-forward.sh`

### Pods not starting?
1. Check events: `kubectl get events --sort-by='.lastTimestamp'`
2. Check pod details: `kubectl describe pod <pod-name>`
3. Verify images are loaded: `podman exec -it micro-gke-control-plane crictl images`

### Port forwarding lost after terminal close?
- Port forwarding runs in background but is tied to the terminal session
- Restart with: `./start-port-forward.sh`

## 🎯 Architecture

```
┌─────────────────────────────────────────┐
│         Browser (localhost)             │
│                                         │
│  localhost:30001    localhost:30002     │
└──────────┬───────────────┬──────────────┘
           │               │
           │ Port Forward  │ Port Forward
           │               │
┌──────────▼───────────────▼──────────────┐
│       Kubernetes Cluster (Kind)         │
│                                         │
│  ┌─────────────────┐  ┌──────────────┐ │
│  │  mf1-nextjs     │  │  mf2-vuejs   │ │
│  │  Service:3000   │  │  Service:80  │ │
│  │  NodePort:30001 │  │  NodePort:   │ │
│  │                 │  │  30002       │ │
│  │  ┌───────────┐  │  │  ┌─────────┐│ │
│  │  │  Pod 1    │  │  │  │  Pod 1  ││ │
│  │  │  Pod 2    │  │  │  │  Pod 2  ││ │
│  │  └───────────┘  │  │  └─────────┘│ │
│  └─────────────────┘  └──────────────┘ │
└─────────────────────────────────────────┘
```

## 📝 Notes

- **Kind Limitation**: NodePort services in Kind are not directly accessible from the host
- **Solution**: Port forwarding bridges the gap between localhost and the cluster
- **Production**: In cloud environments (GKE, EKS, AKS), NodePort or LoadBalancer services work without port forwarding
- **Environment Variables**: Apps use `.env.production` for NodePort URLs (30001, 30002)
