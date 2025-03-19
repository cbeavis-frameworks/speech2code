#!/bin/bash

# This script copies the .env file to the app bundle during build
# It will be executed as a Run Script build phase in Xcode

# Get the source .env file path
SRC_ENV_FILE="${SRCROOT}/Speech2Code/.env"

# Get the destination path in the app bundle
DEST_DIR="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/Contents/Resources"
DEST_ENV_FILE="${DEST_DIR}/.env"

# Create the destination directory if it doesn't exist
mkdir -p "${DEST_DIR}"

# Copy the .env file
if [ -f "${SRC_ENV_FILE}" ]; then
    echo "Copying .env file to app bundle"
    cp "${SRC_ENV_FILE}" "${DEST_ENV_FILE}"
else
    echo "Warning: .env file not found at ${SRC_ENV_FILE}"
fi
