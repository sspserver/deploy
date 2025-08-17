include .install.env
export

export PROJECT_DIR=$(PWD)

PROJECT_WORKSPACE ?= sspdev
DOCKER_COMPOSE := docker compose -p $(PROJECT_WORKSPACE)

.PHONY: build-env
build-env: ## Build the environment for Docker Compose
	@echo "Building environment for Docker Compose..."
	@bash -c 'set -a; source ./.install.env; set +a; mkdir -p ./app-ssp; envsubst < "../standalone/app-ssp/.tmpl.env" > ./app-ssp/.env'
	@bash -c 'set -a; source ./.install.env; set +a; mkdir -p ./app-api; envsubst < "../standalone/app-api/.tmpl.env" > ./app-api/.env'
	@bash -c 'set -a; source ./.install.env; set +a; mkdir -p ./postgres; envsubst < "../standalone/postgres/.tmpl.env" > ./postgres/.env'
	@bash -c 'set -a; source ./.install.env; set +a; mkdir -p ./app-control; envsubst < "../standalone/app-control/.tmpl.env" > ./app-control/.env'
	@bash -c 'set -a; source ./.install.env; set +a; mkdir -p ./eventstream; envsubst < "../standalone/eventstream/.tmpl.env" > ./eventstream/.env'

.PHONY: update
build-compose: build-env ## Build the Docker Compose services
	docker compose \
		-f ../standalone/docker-compose.base.yml \
		-f ../standalone/eventstream/docker-compose.yml \
		-f ../standalone/postgres/docker-compose.yml \
		-f ../standalone/clickhouse/docker-compose.yml \
		-f ../standalone/redis/docker-compose.yml \
		config | sed "s|$$(dirname $$PWD)|..|g" > docker-compose.yml

.PHONY: run
run: ## Run the control service
	$(DOCKER_COMPOSE) up control

.PHONY: db-cli
db-cli: ## Open development database
	$(DOCKER_COMPOSE) exec $(DOCKER_DATABASE_NAME) psql -U $(POSTGRES_USER) $(POSTGRES_DB)

.PHONY: ch-cli
ch-cli: ## Connect to dev clickhouse
	$(DOCKER_COMPOSE) exec clickhouse-server clickhouse-client

.PHONY: help
help: ## Show this help message
	# Extract name of the command and description
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' Makefile | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
	@echo "Use 'make <target>' to execute a target. Targets with '##' are documented."
	@echo "Use 'make help' to see this message."

.DEFAULT_GOAL := help
