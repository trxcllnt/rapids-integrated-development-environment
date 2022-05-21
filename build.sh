#! /usr/bin/env bash

set -Eeo pipefail

docker compose build --force-rm --pull     01-base
docker compose build --force-rm --parallel 02-cpp 02-mamba
docker compose build --force-rm --parallel 03-python 03-cudf-cpp 03-ucx-cpp
docker compose build --force-rm --parallel 04-code-server 04-cudf-python 04-ucx-python

# docker system prune -f
