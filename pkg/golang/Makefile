include ../common.mk

BRANCH=master

# the last SHA before bump to go 1.23 and removing 1.21
# we still use 1.21 for now
SHA=3187a722bf31fb8b91df2b8c929fee4af9332460

all: golang

.PHONY: golang
golang: folders
	cd $(BUILD_DIR) && \
	rm -rf golang && \
	git clone --branch $(BRANCH) https://github.com/docker-library/golang.git && \
	cd golang && \
	git reset --hard $(SHA) && \
	for patch in $(PATCH_FOLDER)/*; do \
		patch -p1 < $$patch; \
	done && \
	cd $(GOLANG_VERSION)/unstable && \
	docker build -t $(GOLANG_IMAGE) .

distclean:
	rm -rf $(BUILD_DIR)
	docker rmi $(GOLANG_IMAGE)