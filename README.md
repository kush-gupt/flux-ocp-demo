# Laghos Sedov Blast Wave Visualization Demo

A demonstration of high-order Lagrangian hydrodynamics simulation with live browser-based visualization on OpenShift 4.20, using the Flux Framework Operator and GLVis-JS.

## Overview

This demo showcases:

- **Laghos**: High-order Lagrangian hydrodynamics miniapp solving the Sedov blast wave problem
- **Flux Operator**: Kubernetes operator for running HPC workloads with the Flux Framework scheduler
- **GLVis-JS**: Browser-based visualization of finite element simulation data
- **OpenShift 4.20**: Enterprise Kubernetes platform with integrated security and routing

```
┌─────────────────────────────────────────────────────────────┐
│                    OpenShift 4.20 Cluster                   │
│                                                             │
│  ┌─────────────────┐     ┌─────────────────────────────┐   │
│  │  Flux Operator  │     │     Laghos MiniCluster      │   │
│  │                 │────▶│  ┌─────────┐  ┌─────────┐   │   │
│  │                 │     │  │ Pod 0   │  │ Pod 1   │   │   │
│  └─────────────────┘     │  │ (Flux   │  │ (Flux   │   │   │
│                          │  │ Broker) │  │ Worker) │   │   │
│                          │  └────┬────┘  └────┬────┘   │   │
│                          └───────┼────────────┼────────┘   │
│                                  │            │            │
│                                  └─────┬──────┘            │
│                                        │ GLVis Socket      │
│                                        ▼                   │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              GLVis-JS Web Server                    │   │
│  │  ┌─────────────┐  ┌──────────────┐  ┌───────────┐   │   │
│  │  │ Socket Recv │──│ WS Proxy     │──│ HTTP UI   │   │   │
│  │  │ Port 19916  │  │ Port 8080    │  │ Port 8000 │   │   │
│  │  └─────────────┘  └──────────────┘  └─────┬─────┘   │   │
│  └───────────────────────────────────────────┼─────────┘   │
│                                              │             │
│  ┌───────────────────────────────────────────┼─────────┐   │
│  │              OpenShift Route              │         │   │
│  └───────────────────────────────────────────┼─────────┘   │
└──────────────────────────────────────────────┼─────────────┘
                                               │
                                               ▼
                                        ┌─────────────┐
                                        │   Browser   │
                                        │  (GLVis UI) │
                                        └─────────────┘
```

## Prerequisites

- OpenShift 4.20 cluster access with cluster-admin privileges
- `oc` CLI installed and configured
- GitHub account (for container registry access)

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/kush-gupt/flux-ocp-demo.git
cd flux-ocp-demo
```

### 2. Login to OpenShift

```bash
oc login --token=<your-token> --server=<your-cluster-api>
```

### 3. Deploy the Demo

```bash
# Make the script executable
chmod +x scripts/demo.sh

# Deploy everything
./scripts/demo.sh deploy
```

### 4. Access the Visualization

After deployment, the script will display the GLVis URL:

```
https://glvis-server-laghos-demo.apps.<cluster-domain>
```

Open this URL in your browser to see the live Sedov blast wave visualization.

## Manual Deployment

If you prefer to deploy components individually:

### Install Flux Operator

```bash
oc apply -k deploy/flux-operator
```

### Deploy GLVis Server

```bash
oc apply -k deploy/glvis-server
```

### Run Laghos Simulation

```bash
oc apply -k deploy/laghos-sedov
```

## ArgoCD Deployment (GitOps)

For GitOps-based deployment using ArgoCD:

```bash
# Ensure ArgoCD/OpenShift GitOps is installed
oc apply -f deploy/argocd/application.yaml
```

## Demo Commands

```bash
# Show status of all components
./scripts/demo.sh status

# Run a new simulation
./scripts/demo.sh simulate

# Clean up demo resources (keeps Flux Operator)
./scripts/demo.sh cleanup

# Full cleanup including Flux Operator
./scripts/demo.sh full-cleanup
```

## Sedov Blast Wave Problem

The Sedov blast wave is a classic test problem in computational hydrodynamics. It models the self-similar evolution of a strong shock wave from a point explosion in a uniform medium.

### Simulation Parameters

| Parameter | Value | Description |
|-----------|-------|-------------|
| `-p 1` | Sedov blast | Problem type |
| `-dim 2` | 2D | Spatial dimension |
| `-rs 3` | Level 3 | Mesh refinement |
| `-tf 0.8` | 0.8 | Final simulation time |
| `-pa` | Partial assembly | Efficient computation mode |
| `-vis` | Enabled | GLVis visualization |
| `-vs 50` | Every 50 steps | Visualization interval |

## Container Images

Images are automatically built via GitHub Actions and pushed to GitHub Container Registry:

- `ghcr.io/kush-gupt/laghos-sedov:latest` - Laghos with Flux and GLVis support
- `ghcr.io/kush-gupt/glvis-js-server:latest` - GLVis-JS web server with WebSocket proxy

## Project Structure

```
flux-ocp-demo/
├── .github/
│   └── workflows/
│       └── build-images.yaml    # GitHub Actions CI
├── containers/
│   ├── laghos-sedov/
│   │   └── Containerfile        # Laghos container
│   └── glvis-js-server/
│       └── Containerfile        # GLVis-JS container
├── deploy/
│   ├── flux-operator/           # Flux Operator manifests
│   ├── glvis-server/            # GLVis-JS deployment
│   ├── laghos-sedov/            # Laghos MiniCluster
│   └── argocd/                  # ArgoCD applications
├── scripts/
│   └── demo.sh                  # Demo deployment script
└── README.md
```

## Troubleshooting

### Pods not starting

Check SCC permissions:

```bash
oc get pods -n laghos-demo -o yaml | grep -A5 securityContext
oc adm policy who-can use scc flux-scc
```

### GLVis not receiving data

Verify network connectivity:

```bash
oc exec -it <laghos-pod> -n laghos-demo -- nc -zv glvis-server 19916
```

### Viewing simulation logs

```bash
oc logs -f -l job-name=laghos-sedov -n laghos-demo
```

## References

- [Laghos](https://github.com/CEED/Laghos) - High-order Lagrangian hydrodynamics miniapp
- [Flux Framework](https://flux-framework.org/) - Next-generation HPC resource manager
- [Flux Operator](https://github.com/flux-framework/flux-operator) - Kubernetes operator for Flux
- [GLVis](https://glvis.org/) - Finite element visualization tool
- [GLVis-JS](https://github.com/GLVis/glvis-js) - JavaScript/WebAssembly version of GLVis
- [MFEM](https://mfem.org/) - Finite element library

## License

This project is licensed under the MIT License. See individual component repositories for their respective licenses.
