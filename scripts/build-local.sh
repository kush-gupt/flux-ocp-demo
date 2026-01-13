#!/bin/bash
#
# Build container images locally using podman/buildah
# and push to GitHub Container Registry
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
REGISTRY="${REGISTRY:-ghcr.io}"
IMAGE_PREFIX="${IMAGE_PREFIX:-kush-gupt}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${SCRIPT_DIR}/.."

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check for podman or buildah
    if command -v podman &> /dev/null; then
        BUILD_CMD="podman"
    elif command -v buildah &> /dev/null; then
        BUILD_CMD="buildah"
    else
        log_error "Neither podman nor buildah found. Please install one of them."
        exit 1
    fi
    
    log_info "Using ${BUILD_CMD} for container builds"
}

login_registry() {
    log_info "Logging into ${REGISTRY}..."
    
    if [ -z "${GITHUB_TOKEN:-}" ]; then
        log_info "GITHUB_TOKEN not set. Please login manually:"
        echo "  podman login ${REGISTRY}"
        echo ""
        echo "Or set GITHUB_TOKEN environment variable and re-run"
        return 0
    fi
    
    echo "${GITHUB_TOKEN}" | podman login ${REGISTRY} -u "${GITHUB_USER:-${IMAGE_PREFIX}}" --password-stdin
}

build_laghos() {
    log_info "Building Laghos Sedov image..."
    
    cd "${PROJECT_DIR}/containers/laghos-sedov"
    
    if [ "${BUILD_CMD}" = "podman" ]; then
        podman build \
            -t "${REGISTRY}/${IMAGE_PREFIX}/laghos-sedov:latest" \
            -f Containerfile \
            .
    else
        buildah bud \
            -t "${REGISTRY}/${IMAGE_PREFIX}/laghos-sedov:latest" \
            -f Containerfile \
            .
    fi
    
    log_success "Laghos Sedov image built"
}

build_glvis() {
    log_info "Building GLVis-JS Server image..."
    
    cd "${PROJECT_DIR}/containers/glvis-js-server"
    
    if [ "${BUILD_CMD}" = "podman" ]; then
        podman build \
            -t "${REGISTRY}/${IMAGE_PREFIX}/glvis-js-server:latest" \
            -f Containerfile \
            .
    else
        buildah bud \
            -t "${REGISTRY}/${IMAGE_PREFIX}/glvis-js-server:latest" \
            -f Containerfile \
            .
    fi
    
    log_success "GLVis-JS Server image built"
}

push_images() {
    log_info "Pushing images to ${REGISTRY}..."
    
    podman push "${REGISTRY}/${IMAGE_PREFIX}/laghos-sedov:latest"
    podman push "${REGISTRY}/${IMAGE_PREFIX}/glvis-js-server:latest"
    
    log_success "Images pushed to ${REGISTRY}/${IMAGE_PREFIX}/"
}

usage() {
    echo "Build container images locally"
    echo ""
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo "  all       Build and push all images"
    echo "  build     Build all images locally"
    echo "  laghos    Build only Laghos image"
    echo "  glvis     Build only GLVis image"  
    echo "  push      Push images to registry"
    echo "  login     Login to container registry"
    echo ""
    echo "Environment Variables:"
    echo "  REGISTRY      Container registry (default: ghcr.io)"
    echo "  IMAGE_PREFIX  Image prefix/owner (default: kush-gupt)"
    echo "  GITHUB_TOKEN  GitHub token for registry login"
}

main() {
    case "${1:-}" in
        all)
            check_prerequisites
            login_registry
            build_laghos
            build_glvis
            push_images
            ;;
        build)
            check_prerequisites
            build_laghos
            build_glvis
            ;;
        laghos)
            check_prerequisites
            build_laghos
            ;;
        glvis)
            check_prerequisites
            build_glvis
            ;;
        push)
            check_prerequisites
            login_registry
            push_images
            ;;
        login)
            login_registry
            ;;
        *)
            usage
            exit 1
            ;;
    esac
}

main "$@"
