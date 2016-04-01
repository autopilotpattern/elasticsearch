MAKEFLAGS += --warn-undefined-variables
SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail
.DEFAULT_GOAL := build
.PHONY:	*

export COMPOSE_PROJECT_NAME := es
export COMPOSE_FILE := local-compose.yml

# ----------------------------------------------
# building for  local testing and development. When deploying on production
# environments like Triton, `docker-compose up -d` is sufficient

build:
	docker-compose build

# send the demonstration container up to the Docker Hub
ship:
	docker tag -f es_elasticsearch autopilotpattern/elasticsearch
	docker push autopilotpattern/elasticsearch

# ----------------------------------------------
# for testing against local Docker Engine

clean:
	docker-compose stop || true
	docker-compose rm -f || true

test: clean build
	docker-compose up -d
	docker ps
