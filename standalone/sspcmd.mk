CUR_DIR = $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
export VAGRANT_VAGRANTFILE=./tests/Vagrantfile
export VAGRANT_DEFAULT_PROVIDER=virtualbox

.PHONY: test-docker-debian
test-docker-debian:
	echo "Running tests in Debian"
	@docker run -it --rm \
		-v /var/run/docker.sock:/var/run/docker.sock:ro \
		-v $(CUR_DIR):/var/sspserver -w /var/sspserver \
		debian:11 ./install.sh

tests-init:
	@vagrant init

.PHONY: tests
tests:
	@echo "Running tests"
	@vagrant up
