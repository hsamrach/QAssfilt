#!/usr/bin/env bash
set -euo pipefail

# Make sure $PREFIX/bin exists
mkdir -p "$PREFIX/bin"

# Copy the script from the source directory into $PREFIX/bin
cp QAssfilt-qassfilt_v${PKG_VERSION}/qassfilt.sh "$PREFIX/bin/qassfilt"
chmod +x "$PREFIX/bin/qassfilt"
