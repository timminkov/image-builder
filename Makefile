SHELL := /bin/bash
IMAGE_REPO = circleci/build-image
SHA = $(shell git rev-parse --short HEAD)
VERSION = $(CIRCLE_BUILD_NUM)-$(SHA)
NO_CACHE =

define docker-push-with-retry
    for i in 1 2 3; do docker push $(1); if [ $$? -eq 0 ]; then exit 0; fi; echo "Retrying...."; done; exit 1;
endef

ifeq ($(no_cache), true)
    NO_CACHE = --no-cache
endif

### ubuntu-14.04-XXL
# This build image is used on circleci.com Ubuntu 14.04 fleet.
# This is the fattest image that we manage: many versions of various programming languages
# and services such as MySQL or Redis are installed.
###
build-ubuntu-14.04-XXL:
	docker-cache-shim pull ${IMAGE_REPO}
	echo "Building Docker image ubuntu-14.04-XXL-$(VERSION)"
	docker build $(NO_CACHE) --build-arg IMAGE_TAG=ubuntu-14.04-XXL-$(VERSION) \
	-t $(IMAGE_REPO):ubuntu-14.04-XXL-$(VERSION) \
	-f targets/ubuntu-14.04-XXL/Dockerfile \
	.

push-ubuntu-14.04-XXL:
	docker-cache-shim push ${IMAGE_REPO}:ubuntu-14.04-XXL-$(VERSION)
	$(call docker-push-with-retry,$(IMAGE_REPO):ubuntu-14.04-XXL-$(VERSION))

dump-version-ubuntu-14.04-XXL:
	docker run $(IMAGE_REPO):ubuntu-14.04-XXL-$(VERSION) sudo -H -i -u ubuntu /opt/circleci/bin/pkg-versions.sh | jq . > $(CIRCLE_ARTIFACTS)/versions-ubuntu-14.04-XXL.json; true
	curl -o versions.json.before https://circleci.com/docs/environments/trusty.json
	diff -uw versions.json.before $(CIRCLE_ARTIFACTS)/versions-ubuntu-14.04-XXL.json > $(CIRCLE_ARTIFACTS)/versions-ubuntu-14.04-XXL.diff; true

test-ubuntu-14.04-XXL:
	docker run -d -v ~/image-builder/tests:/home/ubuntu/tests -p 12345:22 --name ubuntu-14.04-XXL-test $(IMAGE_REPO):ubuntu-14.04-XXL-$(VERSION)
	sleep 10
	docker cp tests/insecure-ssh-key.pub ubuntu-14.04-XXL-test:/home/ubuntu/.ssh/authorized_keys
	sudo lxc-attach -n $$(docker inspect --format "{{.Id}}" ubuntu-14.04-XXL-test) -- bash -c "chown ubuntu:ubuntu /home/ubuntu/.ssh/authorized_keys"
	chmod 600 tests/insecure-ssh-key; ssh -i tests/insecure-ssh-key -p 12345 ubuntu@localhost bats tests/unit/ubuntu-14.04-XXL

export-s3-ubuntu-14.04-XX:
	./docker-export $(IMAGE_REPO):ubuntu-14.04-XXL-$(VERSION) > $(IMAGE_REPO):ubuntu-14.04-XXL-$(VERSION).tar.gz
	aws s3 cp ./$(IMAGE_REPO):ubuntu-14.04-XXL-$(VERSION).tar.gz s3://circle-downloads/build-image-ubuntu-14.04-XXL-$(VERSION).tar.gz --acl public-read

ubuntu-14.04-XXL: build-ubuntu-14.04-XXL push-ubuntu-14.04-XXL dump-version-ubuntu-14.04-XXL test-ubuntu-14.04-XXL

### ubuntu-14.04-XXL-enterprise
# This build image is for CircleCI Enterprise customer. The image is very similar to ubuntu-14.04-XXL.
# The only difference is that this image has official Docker installed.
###
build-ubuntu-14.04-XXL-enterprise:
	docker-cache-shim pull ${IMAGE_REPO}
	echo "Building Docker image ubuntu-14.04-XXL-enterprise-$(VERSION)"
	docker build $(NO_CACHE) --build-arg IMAGE_TAG=ubuntu-14.04-XXL-enterprise-$(VERSION) \
	-t $(IMAGE_REPO):ubuntu-14.04-XXL-enterprise-$(VERSION) \
	-f targets/ubuntu-14.04-XXL-enterprise/Dockerfile \
	.

push-ubuntu-14.04-XXL-enterprise:
	docker-cache-shim push ${IMAGE_REPO}:ubuntu-14.04-XXL-enterprise-$(VERSION)
	$(call docker-push-with-retry,$(IMAGE_REPO):ubuntu-14.04-XXL-enterprise-$(VERSION))

dump-version-ubuntu-14.04-XXL-enterprise:
	docker run $(IMAGE_REPO):ubuntu-14.04-XXL-enterprise-$(VERSION) sudo -H -i -u ubuntu /opt/circleci/bin/pkg-versions.sh | jq . > $(CIRCLE_ARTIFACTS)/versions-ubuntu-14.04-XXL-enterprise.json; true
	curl -o versions.json.before https://circleci.com/docs/environments/trusty.json
	diff -uw versions.json.before $(CIRCLE_ARTIFACTS)/versions-enterprise.json > $(CIRCLE_ARTIFACTS)/versions-ubuntu-14.04-XXL-enterprise.diff; true

export-s3-ubuntu-14.04-XX-enterprise:
	./docker-export $(IMAGE_REPO):ubuntu-14.04-XXL-enterprise-$(VERSION) > $(IMAGE_REPO):ubuntu-14.04-XXL-enterprise-$(VERSION).tar.gz
	aws s3 cp ./$(IMAGE_REPO):ubuntu-14.04-XXL-enterprise-$(VERSION).tar.gz s3://circleci-enterprise-assets-us-east-1/containers/circleci-trusty-container-$(VERSION).tar.gz --acl public-read

ubuntu-14.04-XXL-enterprise: build-ubuntu-14.04-XXL-enterprise push-ubuntu-14.04-XXL-enterprise dump-version-ubuntu-14.04-XXL-enterprise
