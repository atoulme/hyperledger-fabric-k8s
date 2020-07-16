#!/bin/bash
set -e
# Builds and deploys the frontend application to minikube

cp -R ../fabric-kube/hlf-kube/crypto-config artifacts/
docker build -t frontend .
helm upgrade --install frontend chart/frontend