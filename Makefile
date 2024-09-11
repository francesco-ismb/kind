
DEBIAN_VERSION=sid
PWD=$(shell pwd)
BIN_DIR=$(PWD)/bin
PATCH_FOLDER=$(PWD)/patches
REGISTRY=ghcr.io/go-riscv

PKG_DIR := $(PWD)/pkg
PKG_LIST := $(notdir $(wildcard $(PWD)/pkg/*))
PKG_LIST := golang protobuf release etcd kubernetes kind

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
		if [ -d $(PKG_DIR)/"$$folder" ]; then \
			cd $(PKG_DIR)/"$$folder" && make distclean; \
		fi \
	done
	rm -rf $(BIN_DIR)

.PHONY: folders
folders:
	mkdir -p $(BIN_DIR)

####################################################
# kind cluster and app deployment			 	   #
####################################################
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

