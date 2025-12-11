# Podman Users Guide for GKE Deployment

## Quick Reference

### Initial Setup (One-time)

```bash
# 1. Install Podman (if not already installed)
brew install podman  # macOS
# For Linux: https://podman.io/getting-started/installation

# 2. Verify installation
podman --version

# 3. Login to Google Cloud
gcloud auth login

# 4. Authenticate Podman with GCR
./setup-podman-gcr.sh
```

### Deploy to GKE

```bash
# Run the automated deployment script
./deploy-to-gke.sh
```

The script automatically:
- Authenticates Podman with Google Container Registry
- Builds images using Podman
- Pushes to GCR
- Deploys to GKE

### Manual Commands

#### Authenticate with GCR
```bash
# Method 1: Using helper script
./setup-podman-gcr.sh

# Method 2: Manual authentication
gcloud auth configure-docker gcr.io
gcloud auth print-access-token | podman login -u oauth2accesstoken --password-stdin gcr.io
```

#### Build and Push Images
```bash
# Set your project ID
export PROJECT_ID="your-project-id"

# Build and push mf1
cd mf1
podman build -t gcr.io/$PROJECT_ID/mf1-nextjs:latest .
podman push gcr.io/$PROJECT_ID/mf1-nextjs:latest
cd ..

# Build and push mf2
cd mf2
podman build -t gcr.io/$PROJECT_ID/mf2-vue:latest .
podman push gcr.io/$PROJECT_ID/mf2-vue:latest
cd ..
```

#### Test Images Locally
```bash
# Test Next.js app
podman run -p 3000:3000 gcr.io/$PROJECT_ID/mf1-nextjs:latest

# Test Vue.js app
podman run -p 8080:80 gcr.io/$PROJECT_ID/mf2-vue:latest
```

## Podman vs Docker Differences

| Feature | Podman | Docker |
|---------|--------|--------|
| Daemon | No daemon (daemonless) | Requires Docker daemon |
| Root access | Can run rootless | Usually requires root |
| Command syntax | `podman` | `docker` |
| GCR authentication | Manual token refresh | Automatic via gcloud |

## Common Issues and Solutions

### Issue: "unauthorized: authentication required"

**Solution:** Your GCR token has expired (they last ~1 hour)

```bash
# Re-authenticate
./setup-podman-gcr.sh
```

### Issue: "Error: short-name resolution enforced"

**Solution:** Use full image names with registry prefix

```bash
# Wrong
podman pull alpine

# Correct
podman pull docker.io/alpine:latest
```

### Issue: Podman can't push to gcr.io

**Solution:** Ensure you're authenticated and have permissions

```bash
# Check authentication
podman login gcr.io

# Should show: Login Succeeded!
# If not, run:
./setup-podman-gcr.sh
```

### Issue: "denied: Token exchange failed for project"

**Solution:** Verify project ID and permissions

```bash
# Check current project
gcloud config get-value project

# Set correct project
gcloud config set project YOUR_PROJECT_ID

# Enable Container Registry API
gcloud services enable containerregistry.googleapis.com
```

## Podman-Specific Tips

### 1. Rootless Mode
Podman can run without root privileges, which is more secure:

```bash
# Check if running rootless
podman info | grep -i rootless
```

### 2. Podman Machine (macOS)
On macOS, Podman uses a VM:

```bash
# Check machine status
podman machine list

# Start machine if needed
podman machine start

# Check resources
podman machine inspect
```

### 3. Podman Compose
If you want to use docker-compose files:

```bash
# Install podman-compose
brew install podman-compose

# Use it like docker-compose
podman-compose up
```

### 4. Docker Compatibility
Create an alias to use Docker commands:

```bash
# Add to ~/.zshrc or ~/.bashrc
alias docker=podman

# Then you can use docker commands
docker ps
docker build -t myimage .
```

## Best Practices

1. **Keep tokens fresh**: GCR access tokens expire after ~1 hour. Re-authenticate if you get auth errors.

2. **Use full image names**: Always specify the registry prefix
   ```bash
   gcr.io/$PROJECT_ID/image-name:tag
   ```

3. **Tag your images**: Use semantic versioning
   ```bash
   podman tag gcr.io/$PROJECT_ID/app:latest gcr.io/$PROJECT_ID/app:v1.0.0
   ```

4. **Clean up regularly**: Remove unused images
   ```bash
   podman image prune
   ```

5. **Check image sizes**: Keep images lean
   ```bash
   podman images
   ```

## Automation with Podman

### Create a Build Script
```bash
#!/bin/bash
# build-and-push.sh

export PROJECT_ID="your-project-id"

# Authenticate
gcloud auth print-access-token | podman login -u oauth2accesstoken --password-stdin gcr.io

# Build both apps
podman build -t gcr.io/$PROJECT_ID/mf1-nextjs:latest mf1/
podman build -t gcr.io/$PROJECT_ID/mf2-vue:latest mf2/

# Push both apps
podman push gcr.io/$PROJECT_ID/mf1-nextjs:latest
podman push gcr.io/$PROJECT_ID/mf2-vue:latest

echo "Build and push complete!"
```

### GitHub Actions with Podman
```yaml
name: Build and Push with Podman

on: [push]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Install Podman
        run: sudo apt-get update && sudo apt-get install -y podman
      
      - name: Authenticate with GCR
        run: |
          echo "${{ secrets.GCP_TOKEN }}" | podman login -u oauth2accesstoken --password-stdin gcr.io
      
      - name: Build and Push
        run: |
          podman build -t gcr.io/${{ secrets.PROJECT_ID }}/mf1-nextjs:latest mf1/
          podman push gcr.io/${{ secrets.PROJECT_ID }}/mf1-nextjs:latest
```

## Performance Tips

### Multi-stage Build Cache
```bash
# Use BuildKit-style cache
podman build --layers -t myimage .
```

### Parallel Builds
```bash
# Build both images in parallel
(cd mf1 && podman build -t gcr.io/$PROJECT_ID/mf1-nextjs:latest .) &
(cd mf2 && podman build -t gcr.io/$PROJECT_ID/mf2-vue:latest .) &
wait
```

### Registry Mirror (Optional)
Speed up pulls by using a mirror:

```bash
# Edit /etc/containers/registries.conf
[[registry]]
prefix = "docker.io"
location = "docker.io"

[[registry.mirror]]
location = "mirror.gcr.io"
```

## Additional Resources

- [Podman Documentation](https://docs.podman.io/)
- [Podman vs Docker](https://docs.podman.io/en/latest/markdown/podman.1.html#podman-vs-docker)
- [Rootless Containers](https://github.com/containers/podman/blob/main/docs/tutorials/rootless_tutorial.md)
- [GCR Authentication](https://cloud.google.com/container-registry/docs/advanced-authentication)

---

**Need more help?** Check the main [GKE-GUIDE.md](GKE-GUIDE.md) or open an issue.
