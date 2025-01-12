# Default recipe to display all available commands
default:
    @just --list

# Build Osmium in debug mode (default)
build:
    zig build

# Build Osmium with logging enabled
build-debug:
    zig build -Dlog=true -Ddebug-extensions=true

# Build Osmium in release mode
build-release:
    zig build -Doptimize=ReleaseSafe

# Note: Currently the interpreter will show the parsed bytecode output
# but may not fully execute the Python code yet. The output will look like:
# pyc: { ... hex values ... }
run file:
    ./zig-out/osmium {{file}}

# This will run hello.py which tests basic features like:
# - Variable assignments
# - Basic arithmetic
# - Function definitions and calls
# Note: Currently you'll see the bytecode output rather than the actual execution
quick-test: build
    @echo "Running quick test with hello.py..."
    ./zig-out/osmium hello.py

# Run all tests with summary
test:
    zig build test --summary all

# Clean build artifacts
clean:
    rm -rf zig-cache/
    rm -rf zig-out/

# Watch for changes and rebuild (requires entr)
watch:
    find src -name '*.zig' | entr -c just build

# Format all Zig files
fmt:
    find src -name '*.zig' -exec zig fmt {} \;