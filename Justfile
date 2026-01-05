ZIG := "zig"

dev:
    {{ZIG}} build && ./zig-out/osmium hello.py

test:
    {{ZIG}} build test --summary all
