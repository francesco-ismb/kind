include ../common.mk

BRANCH=v0.16.5

all: release

.PHONY: release
release: folders cross debian-base go-runner setcap distroless-iptables
	@echo "Release done"

.PHONY: $(BUILD_DIR)/release
$(BUILD_DIR)/release:
	docker buildx use default
	cd $(BUILD_DIR) && \
		rm -rf release && \
		git clone --branch $(BRANCH) --depth 1 https://github.com/kubernetes/release.git && \
	cd release && \
		for patch in $(PATCH_FOLDER)/*; do \
			patch -p1 < $$patch; \
		done


.PHONY: cross
cross: $(BUILD_DIR)/release
	# Build cross
	echo "Building release image: [cross]" && \
	mkdir -p $(BUILD_DIR)/release/images/build/cross/precompiled && \
	cp $(BIN_DIR)/$(PROTOC_ZIP) $(BUILD_DIR)/release/images/build/cross/precompiled/ && \
	cd $(BUILD_DIR)/release/images/build/cross && \
	PLATFORMS=linux/riscv64 BASEIMAGE=$(GOLANG_IMAGE) REGISTRY=$(REGISTRY) make container

.PHONY: debian-base
debian-base: $(BUILD_DIR)/release
	# Build debian-base
	echo "Building release image: [debian-base]" && \
	cd $(BUILD_DIR)/release/images/build/debian-base && \
	ARCH=riscv64 CONFIG=unstable IMAGE_VERSION=$(DEBIAN_BASE_VERSION) REGISTRY=$(REGISTRY) make build

.PHONY: go-runner
go-runner: $(BUILD_DIR)/release
	# Build go-runner
	echo "Building release image: [go-runner]" && \
	cd $(BUILD_DIR)/release/images/build/go-runner && \
	PLATFORMS=linux/riscv64 DISTROLESS_REGISTRY=$(DISTROLESS_REGISTRY) DISTROLESS_IMAGE=$(DISTROLESS_IMAGE) BUILDER_IMAGE=$(GOLANG_IMAGE) REGISTRY=$(REGISTRY) make container

.PHONY: setcap
setcap: $(BUILD_DIR)/release
	echo "Building release image: [setcap]" && \
	cd $(BUILD_DIR)/release/images/build/setcap && \
	ARCH=riscv64 CONFIG=unstable DEBIAN_BASE_VERSION=$(DEBIAN_BASE_VERSION) BASE_REGISTRY=$(REGISTRY) REGISTRY=$(REGISTRY) make build

.PHONY: distroless-iptables
distroless-iptables: $(BUILD_DIR)/release
	# Build distroless-iptables
	echo "Building release image: [distroless-iptables]" && \
	cd $(BUILD_DIR)/release/images/build/distroless-iptables && \
	ARCH=riscv64 CONFIG=distroless-unstable BASEIMAGE=$(DISTROLESS_IPTABLES_BASEIMAGE) GORUNNERIMAGE=$(REGISTRY)/go-runner-riscv64:v2.3.1-go1.22.0-bookworm.0 BASE_REGISTRY=$(REGISTRY) REGISTRY=$(REGISTRY) make build

distclean:
	rm -rf $(BUILD_DIR)
	docker rmi $(IMAGE)