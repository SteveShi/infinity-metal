# Makefile for infinity-metal — Apple Metal rendering backend for Infinity Engine EE games
# Supports: Baldur's Gate: Enhanced Edition, Baldur's Gate II: Enhanced Edition,
#           Icewind Dale: Enhanced Edition, Planescape Torment: Enhanced Edition

PROJECT_DIR := $(CURDIR)
SRC_DIR     := $(PROJECT_DIR)/src
BUILD_DIR   := $(PROJECT_DIR)/build
SCRIPTS_DIR := $(PROJECT_DIR)/scripts

TARGET        := $(BUILD_DIR)/libInfinityMetal.dylib
TARGET_X86_64 := $(BUILD_DIR)/libInfinityMetal_x86_64.dylib
TARGET_ARM64  := $(BUILD_DIR)/libInfinityMetal_arm64.dylib

CC     := clang
CFLAGS := -Wall -Wextra -O2 -fPIC -fvisibility=hidden -Wno-deprecated-declarations
LDFLAGS := -dynamiclib -ObjC \
           -framework Metal -framework QuartzCore -framework Cocoa \
           -framework CoreGraphics -framework CoreVideo -framework OpenGL \
           -weak_framework MetalFX

# Source files
SRCS_C     := $(wildcard $(SRC_DIR)/*.c)
SRCS_M     := $(wildcard $(SRC_DIR)/*.m)
SRCS_METAL := $(wildcard $(SRC_DIR)/*.metal)

# Object files per architecture
OBJS_X86_64 := $(patsubst $(SRC_DIR)/%.c, $(BUILD_DIR)/x86_64/%.o, $(SRCS_C)) \
               $(patsubst $(SRC_DIR)/%.m, $(BUILD_DIR)/x86_64/%.o, $(SRCS_M))
OBJS_ARM64  := $(patsubst $(SRC_DIR)/%.c, $(BUILD_DIR)/arm64/%.o, $(SRCS_C)) \
               $(patsubst $(SRC_DIR)/%.m, $(BUILD_DIR)/arm64/%.o, $(SRCS_M))

# Metal shader compilation
METALLIB  := $(BUILD_DIR)/shaders.metallib
METAL_HDR := $(BUILD_DIR)/shaders_metal.h

.PHONY: all clean install uninstall resign test

all: $(TARGET)
	@echo "[InfinityMetal] Build complete: $(TARGET)"
	@file "$(TARGET)"

# Directory creation
$(BUILD_DIR) $(BUILD_DIR)/x86_64 $(BUILD_DIR)/arm64:
	@mkdir -p $@

# Metal shader compilation — generates embeddable header
$(METAL_HDR): $(SRCS_METAL) | $(BUILD_DIR)
ifneq ($(SRCS_METAL),)
	xcrun -sdk macosx metal -c $(SRCS_METAL) -o "$(BUILD_DIR)/shaders.air"
	xcrun -sdk macosx metallib "$(BUILD_DIR)/shaders.air" -o "$(METALLIB)"
	(cd "$(BUILD_DIR)" && xxd -i shaders.metallib > shaders_metal.h)
else
	@echo "// No metal shaders yet — placeholder" > "$@"
	@echo "static const unsigned char shaders_metallib[] = {0};" >> "$@"
	@echo "static const unsigned int shaders_metallib_len = 0;" >> "$@"
endif

OBJCFLAGS := $(CFLAGS) -fobjc-arc

# x86_64 compilation
$(BUILD_DIR)/x86_64/%.o: $(SRC_DIR)/%.c $(METAL_HDR) | $(BUILD_DIR)/x86_64
	$(CC) $(CFLAGS) -target x86_64-apple-macos11 -I$(BUILD_DIR) -I$(SRC_DIR) -c $< -o $@

$(BUILD_DIR)/x86_64/%.o: $(SRC_DIR)/%.m $(METAL_HDR) | $(BUILD_DIR)/x86_64
	$(CC) $(OBJCFLAGS) -target x86_64-apple-macos11 -I$(BUILD_DIR) -I$(SRC_DIR) -c $< -o $@

$(TARGET_X86_64): $(OBJS_X86_64)
	$(CC) $(LDFLAGS) -target x86_64-apple-macos11 $^ -o $@

# arm64 compilation
$(BUILD_DIR)/arm64/%.o: $(SRC_DIR)/%.c $(METAL_HDR) | $(BUILD_DIR)/arm64
	$(CC) $(CFLAGS) -target arm64-apple-macos11 -I$(BUILD_DIR) -I$(SRC_DIR) -c $< -o $@

$(BUILD_DIR)/arm64/%.o: $(SRC_DIR)/%.m $(METAL_HDR) | $(BUILD_DIR)/arm64
	$(CC) $(OBJCFLAGS) -target arm64-apple-macos11 -I$(BUILD_DIR) -I$(SRC_DIR) -c $< -o $@

$(TARGET_ARM64): $(OBJS_ARM64)
	$(CC) $(LDFLAGS) -target arm64-apple-macos11 $^ -o $@

# Universal Binary via lipo
$(TARGET): $(TARGET_X86_64) $(TARGET_ARM64)
	lipo -create -output "$@" "$<" "$(word 2,$^)"

# Clean build artifacts
clean:
	rm -rf "$(BUILD_DIR)"

# Install: deploy dylib and launchers to all detected EE games
install: $(TARGET)
	@"$(SCRIPTS_DIR)/install.sh"

# Uninstall: remove patch from all EE games
uninstall:
	@"$(SCRIPTS_DIR)/uninstall.sh"

# Re-sign game with entitlements for DYLD injection
resign:
	@"$(SCRIPTS_DIR)/resign.sh"

# Quick test: build and launch game selector
test: $(TARGET)
	@"$(SCRIPTS_DIR)/launch_metal.sh"
