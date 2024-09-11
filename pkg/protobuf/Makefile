include ../common.mk

BRANCH=23.x

all: protoc

.PHONY: protoc
protoc: folders
	cd $(BUILD_DIR) && \
	rm -rf protobuf && \
	git clone --branch $(BRANCH) --depth 1 https://github.com/protocolbuffers/protobuf.git && \
	cd protobuf && \
	for patch in $(PATCH_FOLDER)/*; do \
		patch -p1 < $$patch; \
	done && \
	bazel build //pkg:protoc_release && \
	cp bazel-bin/pkg/protoc-23.4-unknown.zip $(BIN_DIR)/$(PROTOC_ZIP) && \
	bazel shutdown

distclean:
	rm -rf $(BUILD_DIR)
