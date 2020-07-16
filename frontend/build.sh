#!/bin/bash
set -e
# Builds and deploys the frontend application to minikube

cp -R ../fabric-kube/hlf-kube/crypto-config artifacts/
version=`date +%s`
docker build -t frontend:$version .
helm upgrade --install --set image.tag=frontend:$version frontend chart/frontend