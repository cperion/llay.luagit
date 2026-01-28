# =============================================================================
# Llay - High-Performance Layout Engine for LuaJIT
# =============================================================================

# Compiler and flags
CC = gcc
CFLAGS = -Wall -Wextra -O2 -fPIC -Iclay
LDFLAGS = -lm

# Directories
CLAY_DIR = clay
BUILD_DIR = tests/clay_ref
TESTS_DIR = tests
DEMO_LOVE2D_DIR = demo-love2d
DEMO_RAYLIB_DIR = demo-raylib
DEMO_SDL3_DIR = demo-sdl3

# =============================================================================
# Main Targets
# =============================================================================

.PHONY: all clean test demo help

all: $(BUILD_DIR)/libclay_ref.so $(BUILD_DIR)/generate_golden golden-files
	@echo "Build complete!"

help:
	@echo "Llay Build System"
	@echo "================="
	@echo ""
	@echo "Targets:"
	@echo "  make all               - Build Clay reference library and generate golden files"
	@echo "  make test              - Run LuaJIT test suite"
	@echo "  make demo              - Run default demo (Raylib workspace)"
	@echo "  make demo-love2d       - Run Love2D demo"
	@echo "  make demo-raylib       - Run Raylib cards demo (simple)"
	@echo "  make demo-workspace    - Run Raylib workspace demo (full-featured)"
	@echo "  make build-raylib      - Build raylib-lua bindings"
	@echo "  make regenerate        - Regenerate golden test files"
	@echo "  make clean             - Remove build artifacts"
	@echo ""
	@echo "Quick start:"
	@echo "  make demo              - Try the full workspace UI!"
	@echo "  make demo-raylib       - Try the simple cards demo"
	@echo ""

# =============================================================================
# Clay Reference Library (for verification tests)
# =============================================================================

$(BUILD_DIR)/libclay_ref.so: $(BUILD_DIR)/clay_impl.c
	@echo "Building Clay reference library..."
	$(CC) -shared $(CFLAGS) -o $@ $< $(LDFLAGS)

$(BUILD_DIR)/generate_golden: $(BUILD_DIR)/generate_golden.c $(BUILD_DIR)/libclay_ref.so
	@echo "Building golden file generator..."
	$(CC) $(CFLAGS) -o $@ $< -L$(BUILD_DIR) -lclay_ref $(LDFLAGS)

# =============================================================================
# Test Suite
# =============================================================================

golden-files: $(BUILD_DIR)/generate_golden
	@echo "Generating golden reference files..."
	@cd $(BUILD_DIR) && LD_LIBRARY_PATH=. ./generate_golden

regenerate: clean golden-files
	@echo "Golden files regenerated!"

test:
	@echo "Running Llay test suite..."
	@luajit $(TESTS_DIR)/run.lua

# =============================================================================
# Demos
# =============================================================================

demo-love2d:
	@echo "Running Love2D demo..."
	@if command -v love >/dev/null 2>&1; then \
		cd $(DEMO_LOVE2D_DIR) && love .; \
	else \
		echo "Error: Love2D not found. Install with: sudo apt install love (Debian/Ubuntu)"; \
		exit 1; \
	fi

demo-raylib: build-raylib
	@echo "Running Raylib cards demo..."
	@cd $(DEMO_RAYLIB_DIR) && ./raylib-lua/raylua_s cards.lua

demo-workspace: build-raylib
	@echo "Running Raylib workspace demo..."
	@cd $(DEMO_RAYLIB_DIR) && ./raylib-lua/raylua_s main.lua

demo-sdl3:
	@echo "SDL3 demo BROKEN - FFI incompatibility between llay and SDL3_ttf"
	@echo ""
	@echo "The SDL3_ttf FFI bindings are incompatible with llay's FFI context."
	@echo "Use Raylib or Love2D instead."
	@echo ""
	@echo "Try: make demo-workspace"
	@echo ""

demo-sdl3-multi:
	@echo "SDL3 demo BROKEN - FFI incompatibility between llay and SDL3_ttf"
	@echo ""
	@echo "The SDL3_ttf FFI bindings are incompatible with llay's FFI context."
	@echo "Use Raylib or Love2D instead."
	@echo ""
	@echo "Try: make demo-workspace"
	@echo ""

build-raylib:
	@echo "Building raylib-lua bindings..."
	@if [ ! -d "$(DEMO_RAYLIB_DIR)/raylib-lua/raylib" ]; then \
		echo "Initializing raylib-lua submodule..."; \
		git submodule update --init --recursive; \
	fi
	@if [ ! -f "$(DEMO_RAYLIB_DIR)/raylib-lua/raylua_s" ]; then \
		echo "Building raylib-lua..."; \
		cd $(DEMO_RAYLIB_DIR)/raylib-lua && make; \
	else \
		echo "raylib-lua already built"; \
	fi

# =============================================================================
# Cleanup
# =============================================================================

clean:
	@echo "Cleaning build artifacts..."
	@rm -f $(BUILD_DIR)/libclay_ref.so
	@rm -f $(BUILD_DIR)/generate_golden
	@rm -f $(BUILD_DIR)/golden_*.txt
	@echo "Clean complete!"

clean-raylib:
	@echo "Cleaning raylib-lua build..."
	@if [ -d "$(DEMO_RAYLIB_DIR)/raylib-lua" ]; then \
		cd $(DEMO_RAYLIB_DIR)/raylib-lua && make clean; \
	fi

clean-all: clean clean-raylib
	@echo "All build artifacts cleaned!"

# =============================================================================
# Aliases
# =============================================================================

.PHONY: demo demo-love demo-raylib demo-workspace build-raylib clean-raylib clean-all

demo: demo-workspace
demo-love: demo-love2d
demo-ray: demo-raylib
demo-workspace: main
demo-ws: main
main: build-raylib
	@cd $(DEMO_RAYLIB_DIR) && ./raylib-lua/raylua_s main.lua
