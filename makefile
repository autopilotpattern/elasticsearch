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
	docker-compose -pes up -d
	docker-compose -pes scale elasticsearch=3

# for testing against Docker locally
test:
	docker-compose -pes stop
	docker-compose -pes rm -f
	docker-compose -f docker-compose-local.yml -pes up -d
	docker ps
