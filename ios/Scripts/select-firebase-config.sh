#!/bin/bash
# select-firebase-config.sh
#
# Xcode Run Script Build Phase — copies the correct GoogleService-Info.plist
# into the target directory based on the active build configuration.
#
# Debug  → Staging plist
# Release → Production plist
#
# How to add to Xcode:
#   1. Select target (ColocsKitchenRace or CKRAdmin)
#   2. Build Phases → + → New Run Script Phase
#   3. Name it "Select Firebase Config"
#   4. Drag it ABOVE "Copy Bundle Resources"
#   5. Set the shell script to: ${SRCROOT}/Scripts/select-firebase-config.sh

set -e

FIREBASE_DIR="${SRCROOT}/Config/Firebase"

# Determine which target we're building
if [ "${TARGET_NAME}" = "CKRAdmin" ]; then
    STAGING_PLIST="${FIREBASE_DIR}/GoogleService-Info-AdminStaging.plist"
    PROD_PLIST="${FIREBASE_DIR}/GoogleService-Info-AdminProduction.plist"
    DEST="${SRCROOT}/CKRAdmin/GoogleService-Info.plist"
else
    STAGING_PLIST="${FIREBASE_DIR}/GoogleService-Info-Staging.plist"
    PROD_PLIST="${FIREBASE_DIR}/GoogleService-Info-Production.plist"
    DEST="${SRCROOT}/ColocsKitchenRace/GoogleService-Info.plist"
fi

if [ "${CONFIGURATION}" = "Debug" ]; then
    SOURCE="${STAGING_PLIST}"
    echo "note: Using STAGING Firebase config (Debug)"
else
    SOURCE="${PROD_PLIST}"
    echo "note: Using PRODUCTION Firebase config (Release)"
fi

if [ ! -f "${SOURCE}" ]; then
    echo "warning: Firebase config not found at ${SOURCE} — using existing GoogleService-Info.plist"
    exit 0
fi

cp "${SOURCE}" "${DEST}"
echo "note: Copied $(basename "${SOURCE}") → $(basename "${DEST}")"
