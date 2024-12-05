#!/bin/bash

# Paths to directories and files
SERVER_DIR="/minecraft-bedrock"
BACKUP_DIR="/minecraft-bedrock-backup"
UPDATE_DIR="/minecraft-bedrock-update"
API_URL="https://mc-bds-helper.vercel.app/api/latest"
CURRENT_VERSION_FILE="${SERVER_DIR}/version.txt"
TEMP_FILE="/tmp/mc_latest_version.json"

# Fetch the latest version from the API
curl -s -H "user-agent: Mozilla/5.0" "$API_URL" -o "$TEMP_FILE"

if [[ $? -ne 0 ]]; then
    echo "Error: Failed to fetch the latest version information."
    exit 1
fi

LATEST_VERSION=$(jq -r '.version' "$TEMP_FILE")
DOWNLOAD_URL=$(jq -r '.url' "$TEMP_FILE")

if [[ -z "$LATEST_VERSION" || -z "$DOWNLOAD_URL" ]]; then
    echo "Error: Missing version or URL information in the API response."
    exit 1
fi

# Check the current version
if [[ -f "$CURRENT_VERSION_FILE" ]]; then
    CURRENT_VERSION=$(cat "$CURRENT_VERSION_FILE")
else
    CURRENT_VERSION="unknown"
fi

echo "Current version: $CURRENT_VERSION"
echo "Latest version: $LATEST_VERSION"

# Compare versions
if [[ "$LATEST_VERSION" == "$CURRENT_VERSION" ]]; then
    echo "The server is already up-to-date."
    exit 0
fi

echo "Starting update to version $LATEST_VERSION..."

# Backup the current server
echo "Creating a backup..."
cp -r "$SERVER_DIR" "$BACKUP_DIR"

# Download the new server version
echo "Downloading the new server version..."
curl -H "user-agent: Mozilla/5.0" -o "server.zip" "$DOWNLOAD_URL"

if [[ $? -ne 0 ]]; then
    echo "Error: Failed to download the new server version."
    exit 1
fi

# Extract the new version
echo "Extracting the new version..."
unzip -d "$UPDATE_DIR" server.zip

if [[ $? -ne 0 ]]; then
    echo "Error: Failed to extract the new version."
    exit 1
fi

# Remove configuration files
echo "Cleaning configuration files from the new version..."
rm -f "${UPDATE_DIR}/server.properties" "${UPDATE_DIR}/allowlist.json" "${UPDATE_DIR}/permissions.json"

# Stop the server
echo "Stopping the server..."
screen -S minecraft -X stuff "stop$(printf \\r)"

# Update server files
echo "Updating server files..."
cp -r "${UPDATE_DIR}/"* "${SERVER_DIR}/"

# Remove temporary files
echo "Cleaning up temporary files..."
rm -r "$UPDATE_DIR" server.zip

# Update the version file
echo "$LATEST_VERSION" > "$CURRENT_VERSION_FILE"

# Start the server
echo "Starting the server..."
screen -dmS minecraft bash -c "cd $SERVER_DIR && LD_LIBRARY_PATH=. ./bedrock_server"

echo "Update completed successfully to version $LATEST_VERSION!"
