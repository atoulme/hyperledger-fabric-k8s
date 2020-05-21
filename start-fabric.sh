#!/bin/bash
set +ex
curl -sSL http://bit.ly/2ysbOFE | bash -s -- 1.4.1
export PATH=$PATH:$PWD/fabric-samples/bin

cd fabric-kube
./init.sh samples/splunk-fabric samples/chaincode
helm repo add incubator http://storage.googleapis.com/kubernetes-charts-incubator
helm dependency update ./hlf-kube/
helm install hlf-kube hlf-kube -f samples/splunk-fabric/network.yaml -f samples/splunk-fabric/crypto-config.yaml --set peer.launchPods=false --set orderer.launchPods=false
./collect_host_aliases.sh samples/splunk-fabric/
helm upgrade hlf-kube ./hlf-kube -f samples/splunk-fabric/network.yaml -f samples/splunk-fabric/crypto-config.yaml -f samples/splunk-fabric/hostAliases.yaml
cd ../
helm install fabric-logger -f fabric-logger-values.yaml -f fabric-kube/samples/splunk-fabric/hostAliases.yaml ./fabric-logger
counter=0
while [[ $(kubectl get pods | grep ContainerCreating | wc -l) -ne 0 ]];
do
  echo "Waiting 10s for all containers to come up"
  sleep 10
  ((counter++))
  if [[ $counter -ge 12 ]]; then
    echo "CLI container didn't come up after 2 minutes. Keep watching 'kubectl get pods'. When all containers are created, run 'kubectl exec hlf-cli -- bash hlf-scripts/channel-setup.sh'"
    exit 0
  fi
done

kubectl exec hlf-cli -- bash hlf-scripts/channel-setup.sh
