#!/bin/bash
#
# Laghos Sedov Blast Wave Demo Deployment Script
# Deploys the complete demo stack on OpenShift 4.20
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="${NAMESPACE:-laghos-demo}"
FLUX_NAMESPACE="${FLUX_NAMESPACE:-flux-operator}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DIR="${SCRIPT_DIR}/../deploy"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check oc CLI
    if ! command -v oc &> /dev/null; then
        log_error "oc CLI not found. Please install OpenShift CLI."
        exit 1
    fi
    
    # Check cluster connection
    if ! oc whoami &> /dev/null; then
        log_error "Not logged into OpenShift cluster. Please run 'oc login' first."
        exit 1
    fi
    
    # Check cluster version
    CLUSTER_VERSION=$(oc version -o json | jq -r '.openshiftVersion // .serverVersion.gitVersion' 2>/dev/null || echo "unknown")
    log_info "Connected to OpenShift cluster version: ${CLUSTER_VERSION}"
    
    log_success "Prerequisites check passed"
}

install_flux_operator() {
    log_info "Installing Flux Operator..."
    
    # Apply Flux Operator manifests
    oc apply -k "${DEPLOY_DIR}/flux-operator" || {
        # If kustomize fails, try direct apply
        log_warning "Kustomize apply failed, trying direct installation..."
        
        # Create namespace
        oc apply -f "${DEPLOY_DIR}/flux-operator/namespace.yaml"
        
        # Apply SCC
        oc apply -f "${DEPLOY_DIR}/flux-operator/scc.yaml"
        
        # Install Flux Operator from release
        oc apply -f https://github.com/flux-framework/flux-operator/releases/download/0.2.1/flux-operator.yaml -n "${FLUX_NAMESPACE}"
    }
    
    # Wait for operator to be ready
    log_info "Waiting for Flux Operator to be ready..."
    oc rollout status deployment/flux-operator-controller-manager -n "${FLUX_NAMESPACE}" --timeout=300s
    
    # Verify CRD is installed
    if oc get crd miniclusters.flux-framework.org &> /dev/null; then
        log_success "Flux Operator installed successfully"
    else
        log_error "MiniCluster CRD not found. Flux Operator installation may have failed."
        exit 1
    fi
}

deploy_glvis_server() {
    log_info "Deploying GLVis Server..."
    
    # Apply GLVis server manifests
    oc apply -k "${DEPLOY_DIR}/glvis-server"
    
    # Wait for deployment to be ready
    log_info "Waiting for GLVis server to be ready..."
    oc rollout status deployment/glvis-server -n "${NAMESPACE}" --timeout=300s
    
    # Get the route URL
    GLVIS_URL=$(oc get route glvis-server -n "${NAMESPACE}" -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
    if [ -n "${GLVIS_URL}" ]; then
        log_success "GLVis Server deployed at: https://${GLVIS_URL}"
    else
        log_warning "GLVis Server deployed but route URL not available yet"
    fi
}

deploy_laghos_simulation() {
    log_info "Deploying Laghos Sedov Blast Simulation..."
    
    # Check if previous MiniCluster exists and delete it
    if oc get minicluster laghos-sedov -n "${NAMESPACE}" &> /dev/null; then
        log_warning "Previous simulation found, cleaning up..."
        oc delete minicluster laghos-sedov -n "${NAMESPACE}" --wait=true
    fi
    
    # Apply Laghos MiniCluster
    oc apply -k "${DEPLOY_DIR}/laghos-sedov"
    
    log_info "Laghos simulation started. Waiting for pods..."
    
    # Wait for pods to be created
    sleep 5
    
    # Watch the simulation
    log_info "Streaming simulation logs..."
    oc logs -f -l job-name=laghos-sedov -n "${NAMESPACE}" --all-containers=true 2>/dev/null || {
        log_warning "Could not stream logs immediately. Simulation may still be starting."
        log_info "Use 'oc logs -f -l job-name=laghos-sedov -n ${NAMESPACE}' to view logs"
    }
}

show_status() {
    log_info "=== Demo Status ==="
    
    echo ""
    log_info "Flux Operator:"
    oc get pods -n "${FLUX_NAMESPACE}" 2>/dev/null || echo "  Not deployed"
    
    echo ""
    log_info "GLVis Server:"
    oc get pods -n "${NAMESPACE}" -l app=glvis-server 2>/dev/null || echo "  Not deployed"
    
    echo ""
    log_info "Laghos Simulation:"
    oc get miniclusters -n "${NAMESPACE}" 2>/dev/null || echo "  Not deployed"
    oc get pods -n "${NAMESPACE}" -l job-name=laghos-sedov 2>/dev/null || echo "  No simulation running"
    
    echo ""
    log_info "Routes:"
    oc get routes -n "${NAMESPACE}" 2>/dev/null || echo "  No routes"
    
    GLVIS_URL=$(oc get route glvis-server -n "${NAMESPACE}" -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
    if [ -n "${GLVIS_URL}" ]; then
        echo ""
        log_success "GLVis Visualization URL: https://${GLVIS_URL}"
    fi
}

cleanup() {
    log_info "Cleaning up demo resources..."
    
    # Delete Laghos simulation
    oc delete minicluster laghos-sedov -n "${NAMESPACE}" --ignore-not-found=true
    
    # Delete GLVis server
    oc delete -k "${DEPLOY_DIR}/glvis-server" --ignore-not-found=true
    
    # Delete namespace
    oc delete namespace "${NAMESPACE}" --ignore-not-found=true
    
    log_success "Cleanup complete"
}

full_cleanup() {
    log_info "Performing full cleanup (including Flux Operator)..."
    
    cleanup
    
    # Delete Flux Operator
    oc delete -k "${DEPLOY_DIR}/flux-operator" --ignore-not-found=true
    oc delete namespace "${FLUX_NAMESPACE}" --ignore-not-found=true
    
    log_success "Full cleanup complete"
}

usage() {
    echo "Laghos Sedov Blast Wave Demo"
    echo ""
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo "  deploy      Deploy the complete demo stack"
    echo "  operator    Install only the Flux Operator"
    echo "  glvis       Deploy only the GLVis server"
    echo "  simulate    Run the Laghos simulation"
    echo "  status      Show current demo status"
    echo "  cleanup     Remove demo resources (keeps Flux Operator)"
    echo "  full-cleanup Remove all resources including Flux Operator"
    echo ""
    echo "Environment Variables:"
    echo "  NAMESPACE        Demo namespace (default: laghos-demo)"
    echo "  FLUX_NAMESPACE   Flux Operator namespace (default: flux-operator)"
}

main() {
    case "${1:-}" in
        deploy)
            check_prerequisites
            install_flux_operator
            deploy_glvis_server
            deploy_laghos_simulation
            show_status
            ;;
        operator)
            check_prerequisites
            install_flux_operator
            ;;
        glvis)
            check_prerequisites
            deploy_glvis_server
            ;;
        simulate)
            check_prerequisites
            deploy_laghos_simulation
            ;;
        status)
            show_status
            ;;
        cleanup)
            cleanup
            ;;
        full-cleanup)
            full_cleanup
            ;;
        *)
            usage
            exit 1
            ;;
    esac
}

main "$@"
