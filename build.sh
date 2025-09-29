#!/usr/bin/env bash
set -euo pipefail

mkdir -p "$PREFIX/bin"

# Copy from whatever top-level folder the tarball extracted
cp */qassfilt.sh "$PREFIX/bin/qassfilt"
chmod +x "$PREFIX/bin/qassfilt"
