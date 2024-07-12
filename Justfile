# This Justfile is used to automate common tasks for the Osmium project using `just` command.

# Define variables that can be reused in multiple commands.
# CC: The command to invoke the Zig compiler.
CC := "zig build"
# CFLAGS: Compiler flags to use when building the project, for example, to enable release-safe optimizations.
CFLAGS := "-Drelease-safe"
# BUILD_DIR: The directory where build artifacts will be placed.
BUILD_DIR := "build"
# EXECUTABLE: The name of the main executable that will be produced.
EXECUTABLE := "osmium"
# TEST_EXECUTABLE: The name of the test executable that will be produced.
TEST_EXECUTABLE := "test_osmium"

# The default recipe that will be run if `just` is called without specifying a recipe.
default:
    # Print a message to the console.
    @echo "Building the Osmium project..."
    # Execute the Zig build command. This uses the configuration specified in the project's build.zig file.
    {{CC}}

# A recipe to build the project.
build:
    # Print a message to the console.
    @echo "Building the Osmium project..."
    # Invoke the Zig compiler to build the project. This will use the build.zig configuration.
    {{CC}}

# A recipe to run the built executable.
run: build
    # Print a message to the console.
    @echo "Running the Osmium VM..."
    # Execute the built executable. This assumes the executable is placed in the BUILD_DIR.
    ./{{BUILD_DIR}}/{{EXECUTABLE}}

# A recipe to run tests.
test:
    # Print a message to the console.
    @echo "Running tests..."
    # Correctly invoke Zig's test building mechanism.
    {{CC}} test
    # Note: Execution of the test executable is handled by Zig and does not need to be explicitly done here.

# A recipe to clean up build artifacts.
clean:
    # Print a message to the console.
    @echo "Cleaning up..."
    # Remove all files in the BUILD_DIR.
    rm -rf {{BUILD_DIR}}/*