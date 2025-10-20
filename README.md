# Osmium

A Python 3.10 interpreter written in Zig, designed to execute Python bytecode with performance in mind.

## Project Status

**Recently migrated to Zig 0.15.1** - Bytecode parsing and marshal system fully working.

### What Works
- Python 3.10 bytecode compilation (PYC generation via CPython)
- Complete PYC format deserialization (Marshal)
- Bytecode instruction decoding (19 opcodes)
- CodeObject parsing with constants, names, and varnames
- Object type system (Int, String, Tuple, CodeObject, None)
- Reference-based object sharing (TYPE_REF)
- Hex dump and bytecode inspection

### In Progress
- VM bytecode execution (implementation exists but commented out)
- Builtin functions - `print()` needed for Hello World
- Stack-based instruction execution
- Garbage collection integration

### Blocked/Needs Work
- GC module missing - currently using ArenaAllocator
- Graph and RefMask evaluation needs Zig 0.15.1 updates
- Some marshal edge cases (filename/name field TYPE_REF handling)

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
```