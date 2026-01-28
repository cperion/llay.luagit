#!/bin/bash
# Run Llay Raylib demos

cd "$(dirname "$0")"

# Default to workspace demo if no argument
if [ $# -eq 0 ]; then
	./raylib-lua/raylua_s main.lua
	exit $?
fi

# Check if raylua_s exists
if [ ! -f "./raylib-lua/raylua_s" ]; then
	echo "Error: raylua_s not found at ./raylib-lua/raylua_s"
	echo ""
	echo "Please initialize and build the raylib-lua submodule:"
	echo "  cd raylib-lua"
	echo "  git submodule init"
	echo "  git submodule update"
	echo "  make"
	exit 1
fi

# Determine which demo to run
if [ "$1" = "workspace" ] || [ "$1" = "work" ] || [ "$1" = "w" ] || [ "$1" = "" ]; then
	echo "Running workspace demo..."
	./raylib-lua/raylua_s main.lua
elif [ "$1" = "cards" ] || [ "$1" = "card" ] || [ "$1" = "c" ] || [ "$1" = "simple" ] || [ "$1" = "s" ]; then
	echo "Running cards demo..."
	./raylib-lua/raylua_s cards.lua
else
	echo "Llay Raylib Demos"
	echo "=================="
	echo ""
	echo "Usage: ./run.sh [demo]"
	echo ""
	echo "Demos:"
	echo "  workspace, work, w  - Full-featured workspace UI (default, recommended)"
	echo "  cards, card, simple, s, c - Basic demo with card grid"
	echo ""
	echo "Controls:"
	echo "  ESC    - Exit"
	echo "  Mouse  - Hover and scroll"
	echo "  Wheel  - Scroll content"
	echo ""
	echo "Example:"
	echo "  ./run.sh workspace"
	echo "  ./run.sh cards"
	echo ""
fi
