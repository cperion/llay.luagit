#!/bin/bash
# extract_clay_types.sh - Extract essential FFI declarations from clay.h

OUTPUT="src/ffi_generated.lua"

cat > "$OUTPUT" << 'EOF'
-- ffi_generated.lua - Auto-generated FFI declarations from clay.h
-- Generated: $(date)

local ffi = require("ffi")

ffi.cdef[[
EOF

echo "// Forward declarations" >> "$OUTPUT"
grep "^typedef struct .*;$" clay/clay.h >> "$OUTPUT" 2>/dev/null
echo "" >> "$OUTPUT"

echo "// Basic types" >> "$OUTPUT"
grep "^typedef struct {" clay/clay.h | while read line; do
    # Extract the struct name by finding line after }
    sed -n '/^typedef struct {/,/^} [a-zA-Z_][a-zA-Z0-9_]*;/p' clay/clay.h | head -50
done
