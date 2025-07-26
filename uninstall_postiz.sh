#!/bin/bash

echo "🧹 Starting Postiz uninstallation..."

# Step 1: Navigate to the Postiz folder (default ~/postiz or /opt/postiz)
INSTALL_DIR="${1:-$HOME/postiz}"

if [ ! -d "$INSTALL_DIR" ]; then
  echo "❌ Installation directory not found at: $INSTALL_DIR"
  echo "👉 Please run the script with the correct directory path:"
  echo "   ./uninstall_postiz.sh /your/custom/path"
  exit 1
fi

cd "$INSTALL_DIR" || exit

# Step 2: Stop and remove Docker containers
echo "🛑 Stopping and removing Docker containers..."
docker compose down

# Step 3: Remove Docker volumes (if any)
echo "🧽 Removing Docker volumes..."
docker volume rm $(docker volume ls -qf dangling=true) 2>/dev/null

# Step 4: Delete installation directory
echo "🗑 Deleting installation directory: $INSTALL_DIR"
rm -rf "$INSTALL_DIR"

# Step 5: Remove any remaining Postiz images (optional)
echo "🧼 Removing Postiz Docker images..."
docker images | grep postiz | awk '{print $3}' | xargs -r docker rmi

echo "✅ Postiz uninstalled successfully!"
