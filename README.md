# RIDE (the <b>R</b>APIDS <b>IDE</b>)

RIDE is a fully containerized remote development environment for working on [NVIDIA RAPIDS](https://github.com/rapidsai). It is the spiritual successor (though near-total rewrite) to [`rapids-compose`](https://github.com/trxcllnt/rapids-compose), which is a set of containerized scripts I hacked together years ago when I first joined the RAPIDS team.

RIDE will launch an standardized and feature-rich remote development environment from a single command.

## Usage

```shell
docker pull pauletaylor/rapids-ide:cpp-builder-cuda11.6.0-ubuntu20.04
docker pull pauletaylor/rapids-ide:code-server-4.3.0-cuda11.6.0-ubuntu20.04

docker run --rm -it --runtime nvidia \
    -v "$PWD:$PWD" \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -e TERM \
    -e DOCKER_USER_HOME="$PWD" \
    -e DOCKERD_GROUP=$(cat /etc/group | grep -F "docker:" | cut -d':' -f3) \
    pauletaylor/rapids-ide:code-server-4.3.0-cuda11.6.0-ubuntu20.04 \
    --link
```

## Development

To build the images, use `docker-compose` with `buildkit`:

```shell
DOCKER_BUILDKIT=1 docker-compose build --force-rm cpp-builder code-server
```

To run and test `code-server` changes, run this:

```shell
docker-compose run --rm \
    -e DOCKERD_GROUP=$(cat /etc/group | grep -F "docker:" | cut -d':' -f3) \
    code-server
```
