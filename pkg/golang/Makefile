include ../common.mk

BRANCH=master
VERSION=1.21
IMAGE=$(REGISTRY)/golang:$(VERSION)-unstable

all: golang

.PHONY: golang
golang: folders
	cd $(BUILD_DIR) && \
	rm -rf golang && \
	git clone --branch $(BRANCH) --depth 1 https://github.com/docker-library/golang.git && \
	cd golang && \
	for patch in $(PATCH_FOLDER)/*; do \
		patch -p1 < $$patch; \
	done && \
	cd $(VERSION)/unstable && \
	docker build -t $(IMAGE) .

distclean:
	rm -rf $(BUILD_DIR)
	docker rmi $(IMAGE)