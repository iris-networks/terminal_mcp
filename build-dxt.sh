#!/bin/bash

# Build script for creating DXT package

set -e

echo "Building Terminal MCP Server for DXT..."

# Clean previous builds
rm -rf dist/
mkdir -p dist/

# Build for multiple platforms
echo "Building binaries..."

# macOS AMD64
GOOS=darwin GOARCH=amd64 go build -o dist/mcp-terminal-server-darwin-amd64 .

# macOS ARM64 (Apple Silicon)
GOOS=darwin GOARCH=arm64 go build -o dist/mcp-terminal-server-darwin-arm64 .

# Linux AMD64
GOOS=linux GOARCH=amd64 go build -o dist/mcp-terminal-server-linux-amd64 .

# Linux ARM64
GOOS=linux GOARCH=arm64 go build -o dist/mcp-terminal-server-linux-arm64 .

# Create DXT package directory
echo "Preparing DXT package..."
mkdir -p dist/dxt-package

# Copy manifest
cp manifest.json dist/dxt-package/

# Copy all binaries
cp dist/mcp-terminal-server-* dist/dxt-package/

# Create a default binary symlink (for current platform)
cd dist/dxt-package
if [[ "$OSTYPE" == "darwin"* ]]; then
    if [[ $(uname -m) == "arm64" ]]; then
        ln -sf mcp-terminal-server-darwin-arm64 mcp-terminal-server
    else
        ln -sf mcp-terminal-server-darwin-amd64 mcp-terminal-server
    fi
else
    if [[ $(uname -m) == "aarch64" ]]; then
        ln -sf mcp-terminal-server-linux-arm64 mcp-terminal-server
    else
        ln -sf mcp-terminal-server-linux-amd64 mcp-terminal-server
    fi
fi
cd ../..

# Copy documentation
cp README.md dist/dxt-package/
cp -r docs/ dist/dxt-package/ 2>/dev/null || true

# Create icon if it doesn't exist
if [ ! -f dist/dxt-package/icon.png ]; then
    echo "Creating placeholder icon..."
    # Create a simple 64x64 PNG icon (placeholder)
    # In a real scenario, you'd have a proper icon file
    echo "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==" | base64 -d > dist/dxt-package/icon.png
fi

# Package as DXT
echo "Creating DXT package..."
cd dist/dxt-package
dxt pack
cd ../..

# Move the DXT file to dist root
mv dist/dxt-package/*.dxt dist/

echo "✅ DXT package created successfully!"
echo "📦 Package location: dist/terminal-mcp.dxt"
echo ""
echo "To install in Claude Desktop:"
echo "1. Open Claude Desktop"
echo "2. Go to Settings > Extensions"
echo "3. Click 'Install Extension'"
echo "4. Select the dist/terminal-mcp.dxt file"