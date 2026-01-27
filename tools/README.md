# Tools

This directory contains utilities for working with the Clay layout engine codebase.

## seek

Interface to clay.h using tree-sitter CLI for querying struct and enum definitions.

### Installation (one-time setup)

```bash
# 1. Clone and build tree-sitter C parser
mkdir -p vendor/parsers
cd vendor/parsers
git clone https://github.com/tree-sitter/tree-sitter-c.git c
cd c
tree-sitter build

# 2. Update tree-sitter config to find parsers (if needed)
jq '.["parser-directories"] += ["'"$(pwd | sed 's|/c||')"'"]' ~/.config/tree-sitter/config.json > /tmp/config.json
mv /tmp/config.json ~/.config/tree-sitter/config.json
```

### Usage

```bash
# List all struct and enum definitions
./tools/seek list

# Show a specific definition
./tools/seek show Clay_Dimensions
./tools/seek show Clay_LayoutConfig

# Find a type
./tools/seek list | grep Clay_Render
```

### How it works

The `seek` tool uses tree-sitter CLI to parse and query `clay/clay.h` with the C grammar parser. It runs queries defined in `list-types.scm` to find:
- Struct definitions (`typedef struct { ... } Name`)
- Enum definitions (`typedef enum { ... } Name`)

The tool extracts the type names and their full definitions by matching the syntax tree nodes.
