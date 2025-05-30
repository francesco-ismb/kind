# Introduction

Kind (Kubernetes in Docker) is a tool that allows to easily bootstrap a Kubernetes cluster in docker containers.

Thanks to go-riscv team that started to port distroless and kind to riscv64 architecture. 

Original project repository: https://github.com/go-riscv/kind

Updated and adapted to Vitamin-V purposes

# Requirements
- git
- python3
- go 1.22
- bazel
- docker
- buildx


# Usage
Ensure to use docker buildkit

`export DOCKER_BUILDKIT=1`

Set GO env variables to prefer IPv4

`export GODEBUG=netdns=go+v4`
`export GOPROXY=https://goproxy.io,direct`

To build everything run:

`make`

Finally, once make will succed, run

`make kind-cluster`

Add ./bin to PATH and configure kubectl

`kubectl cluster-info --context kind-kind`

