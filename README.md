# RIDE (the <b>R</b>APIDS <b>IDE</b>)

RIDE is a fully containerized, standardized, and feature-rich remote development environment for [NVIDIA RAPIDS](https://github.com/rapidsai).

## Usage

```shell
docker pull pauletaylor/rapids-ide:cpp-builder-cuda11.6.0-ubuntu20.04
docker pull pauletaylor/rapids-ide:code-server-4.3.0-cuda11.6.0-ubuntu20.04

# can be anything. this will be `code-server` container's $HOME dir
DOCKER_USER_HOME=/tmp/rapids
DOCKERD_GROUP=$(cat /etc/group | grep -F "docker:" | cut -d':' -f3)

docker run --rm -it --runtime nvidia \
    -e "DOCKERD_GROUP=$DOCKERD_GROUP" \
    -e "DOCKER_USER_HOME=$DOCKER_USER_HOME" \
    -v "$DOCKER_USER_HOME:$DOCKER_USER_HOME" \
    -v /var/run/docker.sock:/var/run/docker.sock \
    pauletaylor/rapids-ide:code-server-4.3.0-cuda11.6.0-ubuntu20.04 \
    --link
```

## Development

To build the images, use `docker-compose` with `buildkit`:

```shell
DOCKER_BUILDKIT=1 docker-compose build --force-rm \
    cpp-builder \
    conda-builder \
    wheel-builder \
    code-server
```

To run and test `code-server` changes, run this:

```shell
docker-compose run --rm \
    -e DOCKERD_GROUP=$(cat /etc/group | grep -F "docker:" | cut -d':' -f3) \
    code-server
```
