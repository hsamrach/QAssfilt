#!/usr/bin/env bash
set -euo pipefail

mkdir -p "$PREFIX/bin"

cp qassfilt.sh "$PREFIX/bin/qassfilt"
chmod +x "$PREFIX/bin/qassfilt"