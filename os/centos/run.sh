#!/usr/bin/env bash
docker rmi centos-kernel-build
docker build . --tag centos-kernel-build
docker run -it --rm -u $(id -u):$(id -g) -v /home/martins3/kernels/v5.15:/data centos-kernel-build
