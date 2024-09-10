PWD=$(shell pwd)
BUILD_DIR=$(PWD)/build
BIN_DIR=$(PWD)/../../bin
PATCH_FOLDER=$(PWD)/patches
REGISTRY=ghcr.io/go-riscv

GOLANG_VERSION=1.21
GOLANG_IMAGE=$(REGISTRY)/golang:$(GOLANG_VERSION)-unstable

PROTOC_ZIP=protoc-23.4-linux-riscv_64.zip

DEBIAN_BASE_VERSION=unstable-v1.0.1

DISTROLESS_REGISTRY=ghcr.io/go-riscv/distroless
DISTROLESS_IMAGE=static-unstable

DISTROLESS_IPTABLES_BASEIMAGE=debian:unstable-slim

.PHONY: folders
folders:
	mkdir -p $(BUILD_DIR)
	mkdir -p $(BIN_DIR)