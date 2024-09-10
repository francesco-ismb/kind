PWD=$(shell pwd)
BUILD_DIR=$(PWD)/build
BIN_DIR=$(PWD)/../../bin
PATCH_FOLDER=$(PWD)/patches
REGISTRY=ghcr.io/go-riscv

.PHONY: folders
folders:
	mkdir -p $(BUILD_DIR)
	mkdir -p $(BIN_DIR)