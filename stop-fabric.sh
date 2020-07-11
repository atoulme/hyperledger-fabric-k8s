helm delete hlf-kube
helm delete fabric-logger
kubectl get pvc | awk '/hlf/{print $1}' | xargs kubectl delete pvc
