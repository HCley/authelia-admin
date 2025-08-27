.DEFAULT_GOAL := help
DOCKER_IMAGE_NAME ?= authelia-admin
DOCKER_IMAGE_TAG ?= latest
DOCKER_CONTAINER_NAME ?= authelia-admin
DOCKER_DEV_IMAGE_NAME ?= authelia-admin-dev
DOCKER_DEV_IMAGE_TAG ?= latest
DOCKER_PORT ?= 9093
DOCKER_NETWORK_NAME ?= authelia
DOCKER_NETWORK_CIDR ?= 192.168.38.0/24


.PHONY: network
network: ## Create Docker network if it doesn't exist
	@docker network ls --format "{{.Name}}" | grep -q "^$(DOCKER_NETWORK_NAME)$$" || \
		docker network create --subnet=$(DOCKER_NETWORK_CIDR) $(DOCKER_NETWORK_NAME)
	@echo "Docker network '$(DOCKER_NETWORK_NAME)' is ready"

.PHONY: build 
build: ## Build Docker image
	npm install
	docker build -t $(DOCKER_IMAGE_NAME):$(DOCKER_IMAGE_TAG) .


.PHONY: build-dev
build-dev: ## Build development Docker image
	docker build -f dev.Dockerfile -t $(DOCKER_DEV_IMAGE_NAME):$(DOCKER_DEV_IMAGE_TAG) .

.PHONY: run
run: network ## Run Docker container
	docker run --rm --network $(DOCKER_NETWORK_NAME) \
		-v ./test-configs/authelia:/config -v ./.test-data/authelia:/data \
		-e NODE_TLS_REJECT_UNAUTHORIZED=0 \
		--name $(DOCKER_CONTAINER_NAME) \
		-p $(DOCKER_PORT):9093 \
		$(DOCKER_IMAGE_NAME):$(DOCKER_IMAGE_TAG)


.PHONY: run-dev
run-dev: network build-dev ## Run development Docker container
	mkdir -p ./.test-data/lldap
	cp ./test-configs/lldap/lldap_config.toml ./.test-data/lldap
	docker run --rm -it \
		-v $(PWD):/app \
		--network $(DOCKER_NETWORK_NAME) \
		-v ./test-configs/authelia:/config \
		-v ./.test-data/authelia:/data \
		--name $(DOCKER_CONTAINER_NAME) \
		-p $(DOCKER_PORT):9093 \
		$(DOCKER_DEV_IMAGE_NAME):$(DOCKER_DEV_IMAGE_TAG)

.PHONY: stop
stop: ## Stop and remove Docker container
	-docker stop $(DOCKER_CONTAINER_NAME)
	-docker rm $(DOCKER_CONTAINER_NAME)

.PHONY: docker-compose-run
docker-compose-run: network ## Run docker-compose with external network
	mkdir -p ./.test-data/lldap
	cp ./test-configs/lldap/lldap_config.toml ./.test-data/lldap
	docker-compose up

.PHONY: all
all: build ## Build docker image

.PHONY: network-remove
network-remove: ## Remove Docker network
	@docker network rm $(DOCKER_NETWORK_NAME) 2>/dev/null

.PHONY: clean
clean: ## Clean up Docker images and local files
	-docker rmi $(DOCKER_IMAGE_NAME):$(DOCKER_IMAGE_TAG)
	-docker rmi $(DOCKER_DEV_IMAGE_NAME):$(DOCKER_DEV_IMAGE_TAG)
	rm -rf ./.test-data
	rm -rf ./node_modules
	rm -rf ./package-lock.json
	rm -rf ./build
	rm -rf /.svelte-kit

.PHONY: help
help:	## Print help
		@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

define print-target
    @printf "Executing target: \033[36m$@\033[0m\n"
endef
