KUBERNETES_VERSION=1.29
DEBIAN_VERSION=sid
PWD=$(shell pwd)
BUILD_DIR=$(PWD)/build
BIN_DIR=$(PWD)/bin
PATCH_FOLDER=$(PWD)/patches
REGISTRY=ghcr.io/go-riscv

GOLANG_BRANCH=master
GOLANG_VERSION=1.21
GOLANG_IMAGE=$(REGISTRY)/golang:$(GOLANG_VERSION)-unstable

PROTOBUF_BRANCH=23.x
PROTOBUF_ZIP=protoc-23.4-linux-riscv_64.zip

RELEASE_BRANCH=v0.16.5

DEBIAN_BASE_VERSION=unstable-v1.0.1

DISTROLESS_REGISTRY=ghcr.io/go-riscv/distroless
DISTROLESS_IMAGE=static-unstable

DISTROLESS_IPTABLES_BASEIMAGE=debian:unstable-slim

ETCD_VERSION=3.5

KIND_VERSION=0.22.0

all: golang protoc release kubetools etcd kind-images

.PHONY: folders
folders:
	mkdir -p $(BUILD_DIR)
	mkdir -p $(BIN_DIR)

.PHONY: golang
golang: folders
	cd $(BUILD_DIR) && \
	rm -rf golang && \
	git clone --branch $(GOLANG_BRANCH) --depth 1 https://github.com/docker-library/golang.git && \
	cd golang && \
	for patch in $(PATCH_FOLDER)/golang/*; do \
		patch -p1 < $$patch; \
	done && \
	cd 1.21/unstable && \
	docker build -t $(GOLANG_IMAGE) .

.PHONY: protoc
protoc: folders
	cd $(BUILD_DIR) && \
	rm -rf protobuf && \
	git clone --branch $(PROTOBUF_BRANCH) --depth 1 https://github.com/protocolbuffers/protobuf.git && \
	cd protobuf && \
	for patch in $(PATCH_FOLDER)/protoc/*; do \
		patch -p1 < $$patch; \
	done && \
	bazel build //pkg:protoc_release && \
	cp bazel-bin/pkg/protoc-23.4-unknown.zip $(BIN_DIR)/$(PROTOBUF_ZIP) && \
	bazel shutdown

.PHONY: release
release:
	docker buildx use default
	cd $(BUILD_DIR) && \
		rm -rf release && \
		git clone --branch $(RELEASE_BRANCH) --depth 1 https://github.com/kubernetes/release.git && \
	cd release && \
		for patch in $(PATCH_FOLDER)/release/*; do \
			patch -p1 < $$patch; \
		done

	# Build cross
	echo "Building release image: [cross]" && \
	mkdir -p $(BUILD_DIR)/release/images/build/cross/precompiled && \
	cp $(BIN_DIR)/$(PROTOBUF_ZIP) $(BUILD_DIR)/release/images/build/cross/precompiled/ && \
	cd $(BUILD_DIR)/release/images/build/cross && \
	PLATFORMS=linux/riscv64 BASEIMAGE=$(GOLANG_IMAGE) REGISTRY=$(REGISTRY) make container

	# Build debian-base
	echo "Building release image: [debian-base]" && \
	cd $(BUILD_DIR)/release/images/build/debian-base && \
	ARCH=riscv64 CONFIG=unstable IMAGE_VERSION=$(DEBIAN_BASE_VERSION) REGISTRY=$(REGISTRY) make build

	# Build go-runner
	echo "Building release image: [go-runner]" && \
	cd $(BUILD_DIR)/release/images/build/go-runner && \
	PLATFORMS=linux/riscv64 DISTROLESS_REGISTRY=$(DISTROLESS_REGISTRY) DISTROLESS_IMAGE=$(DISTROLESS_IMAGE) BUILDER_IMAGE=$(GOLANG_IMAGE) REGISTRY=$(REGISTRY) make container

	echo "Building release image: [setcap]" && \
	cd $(BUILD_DIR)/release/images/build/setcap && \
	ARCH=riscv64 CONFIG=unstable DEBIAN_BASE_VERSION=$(DEBIAN_BASE_VERSION) BASE_REGISTRY=$(REGISTRY) REGISTRY=$(REGISTRY) make build

	# Build distroless-iptables
	echo "Building release image: [distroless-iptables]" && \
	cd $(BUILD_DIR)/release/images/build/distroless-iptables && \
	ARCH=riscv64 CONFIG=distroless-unstable BASEIMAGE=$(DISTROLESS_IPTABLES_BASEIMAGE) GORUNNERIMAGE=$(REGISTRY)/go-runner-riscv64:v2.3.1-go1.22.0-bookworm.0 BASE_REGISTRY=$(REGISTRY) REGISTRY=$(REGISTRY) make build

	@echo "Release done"

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

.PHONY: distclean
distclean:
	rm -rf $(BUILD_DIR)
	rm -rf $(BIN_DIR)
