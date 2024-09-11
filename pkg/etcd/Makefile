include ../common.mk

VERSION=3.5

all: etcd

.PHONY: etcd
etcd: folders
	# Build etcd image
	cd $(BUILD_DIR) && \
		rm -rf etcd && \
		git clone --branch release-$(VERSION) --depth 1 https://github.com/etcd-io/etcd.git
	cd $(BUILD_DIR)/etcd && \
	for patch in $(PATCH_FOLDER)/*; do \
		patch -p1 < $$patch; \
	done
	cd $(BUILD_DIR)/etcd && \
		make && \
		TAG=$(REGISTRY)/etcd BINARYDIR=./bin ./scripts/build-docker $(VERSION)

distclean:
	rm -rf $(BUILD_DIR)
	docker rmi $(IMAGE)