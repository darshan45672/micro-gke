# Deploying Micro Frontends to Google Kubernetes Engine (GKE)

This guide walks you through deploying your Next.js and Vue.js micro frontends to Google Kubernetes Engine.

## Prerequisites

1. **Google Cloud Account** with billing enabled
2. **gcloud CLI** installed and configured
3. **kubectl** installed
4. **Docker** or **Podman** for building images
5. **Sufficient GCP permissions** to create:
   - GKE clusters
   - Artifact Registry repositories
   - Load Balancers

## Step 1: Set Up Google Cloud Project

```bash
# Set your project ID
export PROJECT_ID="your-project-id"
export REGION="us-central1"
export ZONE="us-central1-a"
export CLUSTER_NAME="micro-frontend-cluster"
export REPO_NAME="micro-frontend-repo"

# Configure gcloud
gcloud config set project $PROJECT_ID
gcloud config set compute/region $REGION
gcloud config set compute/zone $ZONE
```

## Step 2: Enable Required APIs

```bash
# Enable necessary Google Cloud APIs
gcloud services enable container.googleapis.com
gcloud services enable artifactregistry.googleapis.com
gcloud services enable compute.googleapis.com
```

## Step 3: Create Artifact Registry Repository

Artifact Registry will store your container images.

```bash
# Create a Docker repository in Artifact Registry
gcloud artifacts repositories create $REPO_NAME \
    --repository-format=docker \
    --location=$REGION \
    --description="Micro frontend container images"

# Configure Docker authentication
gcloud auth configure-docker ${REGION}-docker.pkg.dev
```

## Step 4: Build and Push Container Images

### Build Images Locally

```bash
# Build mf1 (Next.js)
cd mf1
docker build -t mf1-nextjs:latest .
cd ..

# Build mf2 (Vue.js)
cd mf2
docker build -t mf2-vuejs:latest .
cd ..
```

### Tag Images for Artifact Registry

```bash
# Tag mf1
docker tag mf1-nextjs:latest \
    ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/mf1-nextjs:latest

# Tag mf2
docker tag mf2-vuejs:latest \
    ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/mf2-vuejs:latest
```

### Push Images to Artifact Registry

```bash
# Push mf1
docker push ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/mf1-nextjs:latest

# Push mf2
docker push ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/mf2-vuejs:latest
```

## Step 5: Create GKE Cluster

```bash
# Create a GKE cluster with 2 nodes
gcloud container clusters create $CLUSTER_NAME \
    --zone=$ZONE \
    --num-nodes=2 \
    --machine-type=e2-medium \
    --enable-autoscaling \
    --min-nodes=2 \
    --max-nodes=4 \
    --disk-size=20GB

# Get cluster credentials
gcloud container clusters get-credentials $CLUSTER_NAME --zone=$ZONE
```

**Note:** This creates a small cluster. For production, consider:
- Larger machine types (`n1-standard-2` or higher)
- Regional clusters for high availability
- Node pools with specific configurations

## Step 6: Update Kubernetes Manifests for GKE

Create GKE-specific deployment files:

### Create `k8s/gke-mf1-deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mf1-nextjs
  labels:
    app: mf1-nextjs
spec:
  replicas: 2
  selector:
    matchLabels:
      app: mf1-nextjs
  template:
    metadata:
      labels:
        app: mf1-nextjs
    spec:
      containers:
      - name: mf1-nextjs
        image: REGION-docker.pkg.dev/PROJECT_ID/REPO_NAME/mf1-nextjs:latest
        ports:
        - containerPort: 3000
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: mf1-nextjs-service
spec:
  type: LoadBalancer
  selector:
    app: mf1-nextjs
  ports:
    - protocol: TCP
      port: 80
      targetPort: 3000
```

### Create `k8s/gke-mf2-deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mf2-vuejs
  labels:
    app: mf2-vuejs
spec:
  replicas: 2
  selector:
    matchLabels:
      app: mf2-vuejs
  template:
    metadata:
      labels:
        app: mf2-vuejs
    spec:
      containers:
      - name: mf2-vuejs
        image: REGION-docker.pkg.dev/PROJECT_ID/REPO_NAME/mf2-vuejs:latest
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "256Mi"
            cpu: "250m"
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: mf2-vuejs-service
spec:
  type: LoadBalancer
  selector:
    app: mf2-vuejs
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
```

### Update Image References

Replace placeholders in the YAML files:

```bash
# Create GKE-specific manifests with correct image paths
sed "s|REGION|${REGION}|g; s|PROJECT_ID|${PROJECT_ID}|g; s|REPO_NAME|${REPO_NAME}|g" \
    k8s/gke-mf1-deployment.yaml > k8s/gke-mf1-deployment-configured.yaml

sed "s|REGION|${REGION}|g; s|PROJECT_ID|${PROJECT_ID}|g; s|REPO_NAME|${REPO_NAME}|g" \
    k8s/gke-mf2-deployment.yaml > k8s/gke-mf2-deployment-configured.yaml
```

## Step 7: Deploy to GKE

```bash
# Apply the deployments
kubectl apply -f k8s/gke-mf1-deployment-configured.yaml
kubectl apply -f k8s/gke-mf2-deployment-configured.yaml

# Watch deployment progress
kubectl get deployments -w
```

## Step 8: Get External IP Addresses

GKE LoadBalancer services will provision external IPs. This may take 2-5 minutes.

```bash
# Watch for external IPs to be assigned
kubectl get services -w

# Once assigned, get the IPs
export MF1_IP=$(kubectl get service mf1-nextjs-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
export MF2_IP=$(kubectl get service mf2-vuejs-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "Next.js Landing Page: http://${MF1_IP}"
echo "Vue.js Blog Listing: http://${MF2_IP}"
```

## Step 9: Update Application URLs

Your applications currently reference `localhost:30001` and `localhost:30002`. Update them to use the GKE LoadBalancer IPs:

### Update Environment Files

```bash
# Update mf1/.env.production
echo "NEXT_PUBLIC_BLOG_URL=http://${MF2_IP}" > mf1/.env.production

# Update mf2/.env.production
echo "VITE_LANDING_URL=http://${MF1_IP}" > mf2/.env.production
```

### Rebuild and Redeploy

```bash
# Rebuild with new URLs
cd mf1
docker build -t mf1-nextjs:latest .
docker tag mf1-nextjs:latest ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/mf1-nextjs:latest
docker push ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/mf1-nextjs:latest
cd ..

cd mf2
docker build -t mf2-vuejs:latest .
docker tag mf2-vuejs:latest ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/mf2-vuejs:latest
docker push ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/mf2-vuejs:latest
cd ..

# Restart deployments to pull new images
kubectl rollout restart deployment/mf1-nextjs
kubectl rollout restart deployment/mf2-vuejs

# Wait for rollout to complete
kubectl rollout status deployment/mf1-nextjs
kubectl rollout status deployment/mf2-vuejs
```

## Step 10: Test Your Application

```bash
# Get the URLs
echo "🎉 Your micro frontends are deployed!"
echo ""
echo "Next.js Landing Page: http://${MF1_IP}"
echo "Vue.js Blog Listing: http://${MF2_IP}"
echo ""
echo "Open the landing page and click 'View Blogs →' to test navigation!"
```

## Monitoring and Management

### View Logs

```bash
# View Next.js logs
kubectl logs -l app=mf1-nextjs --tail=50 -f

# View Vue.js logs
kubectl logs -l app=mf2-vuejs --tail=50 -f
```

### Check Pod Status

```bash
# Get all pods
kubectl get pods

# Describe a specific pod
kubectl describe pod <pod-name>

# Get pod events
kubectl get events --sort-by='.lastTimestamp'
```

### Scale Applications

```bash
# Scale Next.js app
kubectl scale deployment mf1-nextjs --replicas=3

# Scale Vue.js app
kubectl scale deployment mf2-vuejs --replicas=3
```

### Update Applications

```bash
# After code changes, rebuild and push images
docker build -t ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/mf1-nextjs:v2 mf1/
docker push ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/mf1-nextjs:v2

# Update deployment to use new image
kubectl set image deployment/mf1-nextjs \
    mf1-nextjs=${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/mf1-nextjs:v2

# Monitor rollout
kubectl rollout status deployment/mf1-nextjs
```

## Using Ingress (Optional - Recommended for Production)

Instead of two LoadBalancers, use a single Ingress with path-based routing:

### Create `k8s/gke-ingress.yaml`

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: micro-frontend-ingress
  annotations:
    kubernetes.io/ingress.class: "gce"
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: mf1-nextjs-service
            port:
              number: 80
      - path: /blogs
        pathType: Prefix
        backend:
          service:
            name: mf2-vuejs-service
            port:
              number: 80
```

**Note:** Change Service types from `LoadBalancer` to `ClusterIP` when using Ingress.

## Cost Optimization Tips

1. **Use Preemptible Nodes** (for non-production):
   ```bash
   gcloud container clusters create $CLUSTER_NAME \
       --preemptible \
       --num-nodes=2
   ```

2. **Enable Cluster Autoscaling**:
   ```bash
   gcloud container clusters update $CLUSTER_NAME \
       --enable-autoscaling \
       --min-nodes=1 \
       --max-nodes=3
   ```

3. **Use Autopilot Mode** (managed Kubernetes):
   ```bash
   gcloud container clusters create-auto $CLUSTER_NAME \
       --region=$REGION
   ```

4. **Delete Resources When Not Needed**:
   ```bash
   # Delete cluster
   gcloud container clusters delete $CLUSTER_NAME --zone=$ZONE
   
   # Delete images
   gcloud artifacts docker images delete \
       ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/mf1-nextjs:latest
   ```

## Troubleshooting

### Pods Not Starting

```bash
# Check pod status
kubectl describe pod <pod-name>

# Check if images are accessible
kubectl get events | grep Failed

# Verify image pull secrets (if using private registry)
kubectl get secrets
```

### LoadBalancer IP Not Assigned

```bash
# Check service status
kubectl describe service mf1-nextjs-service

# Verify GKE has permission to create load balancers
gcloud projects get-iam-policy $PROJECT_ID
```

### Application Not Accessible

```bash
# Check firewall rules
gcloud compute firewall-rules list

# Verify service endpoints
kubectl get endpoints

# Test from within cluster
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
    curl http://mf1-nextjs-service
```

## Cleanup

When you're done, delete all resources to avoid charges:

```bash
# Delete Kubernetes resources
kubectl delete -f k8s/gke-mf1-deployment-configured.yaml
kubectl delete -f k8s/gke-mf2-deployment-configured.yaml

# Delete GKE cluster
gcloud container clusters delete $CLUSTER_NAME --zone=$ZONE --quiet

# Delete Artifact Registry images (optional)
gcloud artifacts docker images list ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}
gcloud artifacts docker images delete ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/mf1-nextjs:latest --quiet
gcloud artifacts docker images delete ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/mf2-vuejs:latest --quiet

# Delete repository (optional)
gcloud artifacts repositories delete $REPO_NAME --location=$REGION --quiet
```

## Production Considerations

For production deployments, consider:

1. **Use HTTPS**: Set up SSL certificates with Ingress and Google-managed certificates
2. **Custom Domains**: Configure Cloud DNS for your domain
3. **CI/CD**: Integrate with Cloud Build for automated deployments
4. **Monitoring**: Set up Cloud Monitoring and Logging
5. **Secrets Management**: Use Secret Manager for sensitive data
6. **Network Policies**: Restrict pod-to-pod communication
7. **Resource Quotas**: Set limits on resource usage
8. **Backup**: Enable cluster and persistent volume backups
9. **Multi-Region**: Deploy to multiple regions for high availability
10. **CDN**: Use Cloud CDN for static assets

## Next Steps

- Set up Cloud Build for CI/CD
- Configure Cloud Armor for DDoS protection
- Implement Cloud CDN for better performance
- Set up uptime checks and alerting
- Configure Workload Identity for secure GCP API access

## Resources

- [GKE Documentation](https://cloud.google.com/kubernetes-engine/docs)
- [Artifact Registry Guide](https://cloud.google.com/artifact-registry/docs)
- [GKE Best Practices](https://cloud.google.com/kubernetes-engine/docs/best-practices)
- [Cost Optimization](https://cloud.google.com/kubernetes-engine/docs/how-to/cost-optimization)
