#!/bin/bash
USER=$1
SERVER=$2

if [ $# -eq 3 ]; then
  MASTER_SERVER=$3
elif [ $# -eq 2 ]; then
  MASTER_SERVER=$2
else
  echo "エラー：引数は2つまたは3つで指定してください。"
  exit 1
fi

mv ~/.kube/config ~/.kube/config.tmp
scp ${USER}@${SERVER}:~/.kube/config ~/.kube/config
sed -i "s|https://[^:]*:6443|https://${MASTER_SERVER}:6443|" ~/.kube/config
helm uninstall fb -n elastic
kubectl get pods -n elastic
kubectl delete secret elasticsearch-master-credentials -n elastic
kubectl delete namespace elastic
rm ~/.kube/config
mv ~/.kube/config.tmp ~/.kube/config
