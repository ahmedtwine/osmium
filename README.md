# Osmium

A Python 3.10 interpreter written in Zig, designed to execute Python bytecode with performance in mind.

## Project Status

**Currently in early development** - Working on bytecode parsing and VM foundations.

### What Works ✅
- ✅ Python source file parsing to bytecode (PYC format)
- ✅ Bytecode display and inspection
- ✅ Variables and assignments
- ✅ Basic math operations
- ✅ User-defined function definitions and calls
- ✅ Function returns

### In Progress 🚧
- 🚧 Full VM bytecode execution (currently commented out)
- 🚧 Builtin functions ([Issue #4](https://github.com/Rexicon226/osmium/issues/4))
- 🚧 Complete instruction set implementation

### Planned 📋
- Standard library support
- Error handling and stack traces
- Performance optimizations
- Additional Python version support (currently 3.10 only)

## Architecture

Osmium consists of three main components:

1. **Frontend** (`src/frontend/Python.zig`)
   - Parses Python source files
   - Generates Python bytecode (PYC format)
   - Handles Python 3.10 bytecode specification

2. **Compiler/Marshal** (`src/compiler/Marshal.zig`)
   - Deserializes PYC bytecode
   - Converts bytecode into internal CodeObject representation
   - Manages object references and constants pool

3. **Virtual Machine** (`src/vm/Vm.zig`)
   - Executes Python bytecode instructions
   - Manages runtime state (stack, variables, scopes)
   - Handles Python object lifecycle
   - Implements Python's execution model

## Building

### Requirements

- **Zig 0.15.1**
- macOS or Linux (Windows support planned)

### Installation

```bash
# Install Zig 0.15.1
brew install zig  # macOS
# or use zigup: brew install zigup && zigup 0.15.1

# Build Osmium
zig build

# Run with a Python file
./zig-out/osmium hello.py
```

### Using Just

The project includes a Justfile for common tasks:

```bash
# Build and run
just dev

# Run tests
just test
```

## Example Usage

```python
# hello.py
a = 1
b = 2
c = a + b

def add(x, y):
    return x + y

result = add(5, 3)
```

```bash
$ zig build && ./zig-out/osmium hello.py

=== Python Bytecode (PYC) ===
Length: 272 bytes
Hex dump:

0000: 6f 0d 0d 0a 00 00 00 00 64 52 f2 68 8f 00 00 00
0010: 63 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
...
```

## Next Steps / Roadmap

### Immediate Goals (v0.1)

1. **Uncomment and Fix VM Execution**
   - The VM code in `src/main.zig` (lines 207-224) is currently commented out
   - Need to update Marshal initialization for Zig 0.15.1 compatibility
   - Fix any remaining API issues with Graph and RefMask evaluation
   - Get basic bytecode execution working end-to-end

2. **Implement Core Builtins**
   - `print()` - Essential for "Hello World"
   - `len()` - Required for basic collection operations
   - `range()` - Needed for loops
   - `type()` - Useful for debugging

3. **Control Flow**
   - If/else statements
   - While loops
   - For loops with range()
   - Break and continue

4. **Error Handling**
   - Basic exception raising
   - Try/except blocks
   - Proper error messages

### Medium-term Goals (v0.2)

- Complete instruction set implementation
- List, dict, tuple operations
- String manipulation builtins
- Import system basics
- File I/O operations

### Long-term Goals (v1.0)

- Full Python 3.10 compatibility
- Standard library modules
- Performance optimizations
- Python 3.11+ support
- C extension API compatibility

## Contributing

Contributions are welcome! However, please keep PRs focused and relatively small, as the codebase is still evolving rapidly with frequent rewrites.

**Good PR ideas:**
- Implementing individual builtin functions
- Adding test cases
- Fixing bugs in existing instructions
- Documentation improvements

**Please avoid:**
- Large architectural changes (discuss in an issue first)
- Adding dependencies without discussion
- Changing core VM semantics without benchmarks

## License

GPL-3.0-only - Copyright (c) 2024, David Rubin
