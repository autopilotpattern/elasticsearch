MAKEFLAGS += --warn-undefined-variables
SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail
.DEFAULT_GOAL := build

build:
	docker build -t="0x74696d/triton-elasticsearch" .

ship:
	docker push 0x74696d/triton-elasticsearch

# run a 3-data-node cluster on Triton
run:
	docker-compose -p es up -d
	docker-compose -p es scale elasticsearch=3

# for testing against Docker locally
test:
	docker-compose -p es stop || true
	docker-compose -p es rm -f || true
	docker-compose -p es -f local-compose.yml build
	docker-compose -p es -f local-compose.yml up -d
	docker ps
