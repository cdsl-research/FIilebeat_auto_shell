#!/bin/bash
FILE=$1
USER=$2
SERVER=$3

if [ $# -eq 4 ]; then
  MASTER_SERVER=$4
elif [ $# -eq 3 ]; then
  MASTER_SERVER=$3
else
  echo "エラー：引数は3つまたは4つで指定してください。"
  exit 1
fi

mv ~/.kube/config ~/.kube/config.tmp
scp ${USER}@${SERVER}:~/.kube/config ~/.kube/config
sed -i "s|https://[^:]*:6443|https://${MASTER_SERVER}:6443|" ~/.kube/config
kubectl create namespace elastic
kubectl create secret generic  elasticsearch-master-credentials --from-literal=username=<elasticsearchのユーザ名>   --from-literal=password=<elasticsearchのパスワード> -n elastic
helm install fb elastic/filebeat -n elastic -f ${FILE}
kubectl get pods -n elastic
rm ~/.kube/config
mv ~/.kube/config.tmp ~/.kube/config

