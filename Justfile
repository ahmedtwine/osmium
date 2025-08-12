# ================================================================================================
# OSMIUM BUILD CONFIGURATION FOR macOS
# ================================================================================================
#
# Osmium is a Python interpreter written in Zig that compiles Python 3.10's C API
# to provide Python compatibility while being written in Zig.
#
# IMPORTANT REQUIREMENTS:
# ----------------------
# 1. Zig 0.13.0 is REQUIRED (not 0.14.0!) due to API changes
#    Install with: brew install zigup && zigup fetch 0.13.0
#
# 2. The build process will automatically download and compile:
#    - Python 3.10 C source code
#    - zlib (compression library)
#    - OpenSSL (cryptography library)
#
# HOW THE BUILD WORKS:
# --------------------
# 1. Zig's build system (build.zig) downloads dependencies specified in build.zig.zon
# 2. It compiles Python's C code into a static library (libpython.a)
# 3. It compiles Osmium's Zig code (the VM implementation)
# 4. Links everything together into the 'osmium' executable
# 5. Copies Python's standard library to zig-out/python/Lib
#
# macOS SPECIFIC NOTES:
# --------------------
# - Uses LLVM backend (required for macOS)
# - Uses Apple's system linker instead of LLD
# - Some Linux-only features are disabled (epoll, chroot, etc.)
# - The binary is universal (works on both Intel and Apple Silicon Macs)
#
# CURRENT STATUS:
# --------------
# Osmium is in early development. It can:
# ✓ Parse Python bytecode
# ✓ Handle variables and assignments
# ✓ Perform basic math operations
# ✓ Define and call functions
# ⚠ Execute bytecode (partial - shows bytecode dump currently)
# ✗ Full Python compatibility (work in progress)
#
# ================================================================================================

ZIG := "~/.local/share/zigup/0.13.0/files/zig"

# Get started: just run hello.py

default:
    @just --list

build:
    {{ZIG}} build

build-debug:
    {{ZIG}} build -Dlog=true -Ddebug-extensions=true

build-release:
    {{ZIG}} build -Doptimize=ReleaseSafe

run file:
    ./zig-out/osmium {{file}}

test:
    {{ZIG}} build test --summary all

clean:
    rm -rf zig-cache/ zig-out/

fmt:
    find src -name '*.zig' -exec {{ZIG}} fmt {} \;
