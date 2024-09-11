include ../common.mk

VERSION=0.22.0

all: folders kind node-image

.PHONY: $(BUILD_DIR)/kind
$(BUILD_DIR)/kind:
	cd $(BUILD_DIR) && \
		rm -rf kind && \
		git clone --branch v$(VERSION) --depth 1 https://github.com/kubernetes-sigs/kind.git
	cd $(BUILD_DIR)/kind && \
	for patch in $(PATCH_FOLDER)/*; do \
		patch -p1 < $$patch; \
	done


.PHONY: kind
kind: $(BUILD_DIR)/kind
	# build kind binary
	cd $(BUILD_DIR)/kind && \
		make build && \
		cp bin/kind $(BIN_DIR)/kind

.PHONY: node-image
node-image: kind $(BUILD_DIR)/kubernetes $(BUILD_DIR)/kind local-path-provisioner local-path-helper base kindnetd
	# Build kind node image
	KUBE_BUILD_PULL_LATEST_IMAGES=n \
	KUBE_CROSS_IMAGE=$(REGISTRY)/kube-cross-riscv64 \
	KUBE_CROSS_VERSION=v1.30.0-go1.22.0-bullseye.0 \
	KUBE_GORUNNER_IMAGE=$(REGISTRY)/go-runner-riscv64:v2.3.1-go1.22.0-bookworm.0 \
	KUBE_PROXY_BASE_IMAGE=$(REGISTRY)/distroless-iptables-riscv64:v0.5.1 \
	KUBE_BUILD_SETCAP_IMAGE=$(REGISTRY)/setcap-riscv64:bookworm-v1.0.1 \
	$(BIN_DIR)/kind build node-image --base-image $(REGISTRY)/base:riscv64 $(BUILD_DIR)/kubernetes

.PHONY: local-path-provisioner
local-path-provisioner:
	# Build local-path-provisioner image
	cd $(BUILD_DIR)/kind/images/local-path-provisioner && \
	PLATFORMS=riscv64 TAG=riscv64 REGISTRY=$(REGISTRY) make build

.PHONY: local-path-helper
local-path-helper:
	# Build local-path-helper image
	cd $(BUILD_DIR)/kind/images/local-path-helper && \
	PLATFORMS=riscv64 TAG=riscv64 REGISTRY=$(REGISTRY) make build

.PHONY: base
base:
	# Build kind base image
	cd $(BUILD_DIR)/kind/images/base && \
	PLATFORMS=riscv64 TAG=riscv64 REGISTRY=$(REGISTRY) make build

.PHONY: kindnetd
kindnetd:
	# Build kindnetd image
	cd $(BUILD_DIR)/kind/images/kindnetd && \
	PLATFORMS=riscv64 TAG=riscv64 REGISTRY=$(REGISTRY) KUBE_PROXY_BASE_IMAGE=$(REGISTRY)/distroless-iptables-riscv64:v0.5.1 \
make build

distclean:
	rm -rf $(BUILD_DIR)
	docker rmi $(IMAGE)
