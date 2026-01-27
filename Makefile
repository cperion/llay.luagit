CC = gcc
CFLAGS = -Wall -Wextra -O2 -fPIC -Iclay
LDFLAGS = -lm
CLAY_DIR = clay
BUILD_DIR = tests/clay_ref

.PHONY: all clean test regenerate

all: $(BUILD_DIR)/libclay_ref.so $(BUILD_DIR)/generate_golden golden-files

$(BUILD_DIR)/libclay_ref.so: $(BUILD_DIR)/clay_impl.c
	@echo "Building $@..."
	$(CC) -shared $(CFLAGS) -o $@ $< $(LDFLAGS)

$(BUILD_DIR)/generate_golden: $(BUILD_DIR)/generate_golden.c $(BUILD_DIR)/libclay_ref.so
	@echo "Building $@..."
	$(CC) $(CFLAGS) -o $@ $< -L$(BUILD_DIR) -lclay_ref $(LDFLAGS)

golden-files: $(BUILD_DIR)/generate_golden
	@echo "Generating golden files..."
	@cd $(BUILD_DIR) && LD_LIBRARY_PATH=. ./generate_golden

regenerate: clean golden-files
	@echo "Golden files regenerated!"

test:
	@echo "Running llay test suite..."
	@luajit tests/run.lua

demo:
	@echo "Running Llay Love2D demo..."
	@cd demo-love2d && love .
