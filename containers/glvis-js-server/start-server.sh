#!/bin/bash
set -e

echo "=== GLVis-JS Web Server ==="
echo "HTTP server on port ${HTTP_PORT:-8000}"
echo "GLVis socket listener on port ${GLVIS_PORT:-19916}"
echo ""
echo "Waiting for Laghos to connect and stream visualization data..."

exec python3 /opt/glvis-proxy.py
