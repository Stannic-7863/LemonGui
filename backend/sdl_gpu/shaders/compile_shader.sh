#!/bin/bash
set -e
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$SCRIPT_DIR/source"
OUT_DIR="$SCRIPT_DIR/compiled"

for file in "$SRC_DIR"/*; do
    if [[ -f "$file" ]]; then
        filename=$(basename -- "$file")
        extension="${filename##*.}"
        name="${filename%.*}"
        glslc "$file" -o "$OUT_DIR/$name.$extension.sprv"
        echo "Compiled $filename -> $name.$extension.sprv"
    fi
done
