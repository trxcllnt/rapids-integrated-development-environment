#! /usr/bin/env bash

set -Eeo pipefail

docker compose build --force-rm --pull     01-base
docker compose build --force-rm --parallel 02-cpp 02-mamba
docker compose build --force-rm            03-python
docker compose build --force-rm            04-code-server

docker system prune -f
