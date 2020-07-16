#!/bin/bash
set -e
# Builds and deploys the frontend application to minikube

cp -R ../fabric-kube/hlf-kube/crypto-config artifacts/
imageTag=$(docker build -t frontend . | grep "Successfully built " | awk '{print $3}')
helm upgrade --install --set image.tag=$imageTag frontend chart/frontend