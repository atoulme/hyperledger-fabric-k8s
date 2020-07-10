#!/bin/bash
# Install prometheus-operator
helm repo add stable https://kubernetes-charts.storage.googleapis.com
helm repo update
helm upgrade --install prometheus-operator --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false stable/prometheus-operator

kubectl apply -f signalfx-prometheus-operator/serviceMonitor-hlf.yml

helm repo add signalfx https://dl.signalfx.com/helm-repo
helm repo update
helm upgrade --install signalfx-agent -f signalfx-prometheus-operator/signalfx-values.yaml -f signalfx-prometheus-operator/enable-signalfx.com.yaml signalfx/signalfx-agent