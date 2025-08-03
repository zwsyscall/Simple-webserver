# Directories
SRC_DIR := src
BUILD_DIR := target

# Assembly source files in src/
ASM_SRCS := $(wildcard $(SRC_DIR)/*.asm)

# Object files in target/
OBJS := $(patsubst $(SRC_DIR)/%.asm,$(BUILD_DIR)/%.o,$(ASM_SRCS))

# Output binary
BIN := $(BUILD_DIR)/server-binary

# Default target
all: $(BIN)

# Link object files into final binary
$(BIN): $(OBJS)
	ld -m elf_x86_64 -o $@ $^

# Assemble each .asm into .o
$(BUILD_DIR)/%.o: $(SRC_DIR)/%.asm
	@mkdir -p $(BUILD_DIR)
	nasm -f elf64 $< -o $@

# Run the built program
run: $(BIN)
	./$(BIN)

# Clean build artifacts
clean:
	rm -f $(OBJS) $(BIN)
