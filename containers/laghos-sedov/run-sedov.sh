#!/bin/bash
set -e

echo "=== Laghos Sedov Blast Wave Demo ==="
echo "Initializing environment..."

# Source the spack environment
. /etc/profile.d/z10_spack_environment.sh

# Default parameters
GLVIS_HOST=${GLVIS_HOST:-glvis-server}
GLVIS_PORT=${GLVIS_PORT:-19916}
RS=${RS:-3}
TF=${TF:-0.8}
VS=${VS:-50}
DEV=${DEV:-cpu}

echo "GLVis server: ${GLVIS_HOST}:${GLVIS_PORT}"
echo "Parameters: RS=${RS}, TF=${TF}, VS=${VS}"

# Wait for GLVis server to be ready (optional)
if [ "${WAIT_FOR_GLVIS:-true}" = "true" ]; then
    echo "Waiting for GLVis server..."
    for i in {1..30}; do
        if nc -z ${GLVIS_HOST} ${GLVIS_PORT} 2>/dev/null; then
            echo "GLVis server is ready!"
            break
        fi
        echo "Attempt $i: GLVis server not ready, waiting..."
        sleep 2
    done
fi

cd /opt/laghos

# Run Laghos Sedov blast simulation
# -p 1: Sedov blast problem
# -dim 2: 2D simulation  
# -rs: Refinement level
# -tf: Final time
# -pa: Partial assembly (efficient)
# -vis: Enable GLVis visualization
# -vh: GLVis host
# -vp: GLVis port
# -vs: Visualization steps interval
echo "Running Laghos Sedov blast simulation..."
exec laghos \
    -p 1 \
    -dim 2 \
    -rs ${RS} \
    -tf ${TF} \
    -pa \
    -vis \
    -vh ${GLVIS_HOST} \
    -vp ${GLVIS_PORT} \
    -vs ${VS} \
    --dev ${DEV} \
    "$@"
