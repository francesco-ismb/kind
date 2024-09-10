KUBERNETES_VERSION=1.29
DEBIAN_VERSION=sid
PWD=$(shell pwd)
BUILD_DIR=$(PWD)/build
BIN_DIR=$(PWD)/bin
PATCH_FOLDER=$(PWD)/patches
REGISTRY=ghcr.io/go-riscv

ETCD_VERSION=3.5

KIND_VERSION=0.22.0

PKG_DIR := $(PWD)/pkg
PKG_LIST := $(notdir $(wildcard $(PWD)/pkg/*))
PKG_LIST := golang protobuf release

.PHONY: all
all: folders
	@for folder in $(PKG_LIST); do \
		if [ -d $(PKG_DIR)/"$$folder" ]; then \
			cd $(PKG_DIR)/"$$folder" && make all; \
		fi \
	done

.PHONY: $(PKG_LIST)
$(PKG_LIST):
	@cd $(PKG_DIR)/$@ && make all

.PHONY: distclean
distclean:
	@for folder in $(PKG_LIST); do \
		if [ -d "$$folder" ]; then \
			cd "$$folder" && make distclean; \
		fi \
	done
	rm -rf $(BUILD_DIR)
	rm -rf $(BIN_DIR)

.PHONY: folders
folders:
	mkdir -p $(BUILD_DIR)
	mkdir -p $(BIN_DIR)

.PHONY: kube-sources
kube-sources:
	cd $(BUILD_DIR) && \
		rm -rf kubernetes && \
		git clone --branch release-$(KUBERNETES_VERSION) https://github.com/kubernetes/kubernetes.git && \
	cd $(BUILD_DIR)/kubernetes && \
	for patch in $(PATCH_FOLDER)/kubernetes/*; do \
		patch -p1 < $$patch; \
	done

.PHONY: kubetools
kubetools: kube-sources
	# Build kubectl and kubeadm
	echo "Building kubectl and kubeadm" && \
	cd $(BUILD_DIR)/kubernetes && \
		make kubectl kubeadm
	cp $(BUILD_DIR)/kubernetes/_output/local/go/bin/kubectl $(BIN_DIR)/kubectl
	cp $(BUILD_DIR)/kubernetes/_output/local/go/bin/kubeadm $(BIN_DIR)/kubeadm

	# Build pause
	echo "Building kubernetes image: [pause]" && \
	cd $(BUILD_DIR)/kubernetes/build/pause && \
	ARCH=riscv64 KUBE_CROSS_IMAGE=$(REGISTRY)/kube-cross-riscv64 KUBE_CROSS_VERSION=v1.30.0-go1.22.0-bullseye.0 REGISTRY=$(REGISTRY) make container

.PHONY: etcd
etcd:
	# Build etcd image
	cd $(BUILD_DIR) && \
		rm -rf etcd && \
		git clone --branch release-$(ETCD_VERSION) --depth 1 https://github.com/etcd-io/etcd.git
	cd $(BUILD_DIR)/etcd && \
	for patch in $(PATCH_FOLDER)/etcd/*; do \
		patch -p1 < $$patch; \
	done
	cd $(BUILD_DIR)/etcd && \
		make && \
		TAG=$(REGISTRY)/etcd BINARYDIR=./bin ./scripts/build-docker $(ETCD_VERSION)

.PHONY: kind-sources
kind-sources:
	cd $(BUILD_DIR) && \
		rm -rf kind && \
		git clone --branch v$(KIND_VERSION) --depth 1 https://github.com/kubernetes-sigs/kind.git
	cd $(BUILD_DIR)/kind && \
	for patch in $(PATCH_FOLDER)/kind/*; do \
		patch -p1 < $$patch; \
	done

.PHONY: kind
kind: kind-sources
	# build kind binary
	cd $(BUILD_DIR)/kind && \
		make build && \
		cp bin/kind $(BIN_DIR)/kind

.PHONY: kind-images
kind-images: kind kube-sources kind-sources
	# Build local-path-provisioner image
	cd $(BUILD_DIR)/kind/images/local-path-provisioner && \
	PLATFORMS=riscv64 TAG=riscv64 REGISTRY=$(REGISTRY) make build

	# Build local-path-helper image
	cd $(BUILD_DIR)/kind/images/local-path-helper && \
	PLATFORMS=riscv64 TAG=riscv64 REGISTRY=$(REGISTRY) make build

	# Build kind base image
	cd $(BUILD_DIR)/kind/images/base && \
	PLATFORMS=riscv64 TAG=riscv64 REGISTRY=$(REGISTRY) make build

	# Build kindnetd image
	cd $(BUILD_DIR)/kind/images/kindnetd && \
	PLATFORMS=riscv64 TAG=riscv64 REGISTRY=$(REGISTRY) KUBE_PROXY_BASE_IMAGE=$(REGISTRY)/distroless-iptables-riscv64:v0.5.1 \
make build

	# Build kind node image
	KUBE_BUILD_PULL_LATEST_IMAGES=n \
	KUBE_CROSS_IMAGE=$(REGISTRY)/kube-cross-riscv64 \
	KUBE_CROSS_VERSION=v1.30.0-go1.22.0-bullseye.0 \
	KUBE_GORUNNER_IMAGE=$(REGISTRY)/go-runner-riscv64:v2.3.1-go1.22.0-bookworm.0 \
	KUBE_PROXY_BASE_IMAGE=$(REGISTRY)/distroless-iptables-riscv64:v0.5.1 \
	KUBE_BUILD_SETCAP_IMAGE=$(REGISTRY)/setcap-riscv64:bookworm-v1.0.1 \
	$(BIN_DIR)/kind build node-image --base-image $(REGISTRY)/base:riscv64 $(BUILD_DIR)/kubernetes

.PHONY: kind-cluster
kind-cluster:
	# build kind cluster
	$(BIN_DIR)/kind create cluster --retain --config config/kind.yaml
	$(BIN_DIR)/kind load docker-image $(REGISTRY)/local-path-helper:riscv64
	$(BIN_DIR)/kind load docker-image $(REGISTRY)/local-path-provisioner:riscv64

.PHONY: app-deploy
app-deploy:
	# deploy alpine echo server, client and service
	$(BIN_DIR)/kubectl apply -f config/alpine.yaml

.PHONY: kind-cluster-delete
kind-cluster-delete:
	$(BIN_DIR)/kind delete cluster

