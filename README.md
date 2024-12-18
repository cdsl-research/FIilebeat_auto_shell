# 概要
ログサーバから，他のk3sクラスタのログを収集するためには，その収集対象のk3sクラスタにFilebeatを作成し，ログを送ってもらう必要があります．
しかし，Kubernetesとhelmを使いFilebeatを作成するとき，収集対象のk3sクラスタにもhelmをインストールしたり，yamlファイルを送る必要があり，少々手間がかかります．
そこで，Kubernetes環境と元となるyamlファイルさえあれば，ログサーバからk3sクラスタにFilebeatを作成してくれるシェルを組みました．

# 環境
実行した環境は以下の通りです

**ログサーバ**

Ubuntu 24.04.1
k3s：v1.30.5+k3s1
helm：v3.16.1

**ログ収集対象のサーバ**

Ubuntu 24.04.1
k3s：v1.30.5+k3s1

# 使い方
FIlebeatを作成してくれるcreate/_filebeat.shと，シェルで作成したFilebeatを>削除してくれるdelete/_filebeat.shがある．

## Filebeatを作成

kubectlコマンドを打つためのサーバとmasterノードを分離している場合と，分離していない場合で必要な引数の数がひとつ変わります.
また，elasticsearchのユーザ名とパスワードを入力するべきところがあるので，シェルに直接入力してください

**kubectlコマンド用サーバありの場合のコマンド**
```
./create_filebeat.sh [yamlファイル] [対象クラスタのユーザ名] [ 対象クラスタのkubectlサーバ] [対象クラスタのマスターノード]
```
**kubectlコマンド用サーバなしの場合のコマンド**
```
./create_filebeat.sh [yamlファイル] [対象クラスタのユーザ名] [対象クラスタのマスターノード]
```

**シェルの中身**

```
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

```

**実行結果**

対象のVMに，elasticというネームスペースでElasticsearchに接続するためのSecretとFilebeatのPodが作成されます．
```
cdsl@logs-master:~/log_tool$ ./create_filebeat.sh fb-values.yaml cdsl arita-master2
cdsl@arita-master2's password:
config                                  100% 2961     8.2MB/s   00:00
namespace/elastic created
secret/elasticsearch-master-credentials created
NAME: fb
LAST DEPLOYED: Wed Dec 18 04:47:02 2024
NAMESPACE: elastic
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
1. Watch all containers come up.
  $ kubectl get pods --namespace=elastic -l app=fb-filebeat -w
NAME                READY   STATUS              RESTARTS   AGE
fb-filebeat-gpzcj   0/1     ContainerCreating   0          0s
```

## Filebeatを削除

こちらも先程と同様に，kubectlコマンドを打つためのサーバとmasterノードを分離している場合と，分離していない場合で必要な引数の数がひとつ変わります.

**kubectlコマンド用サーバありの場合のコマンド**
```
./delete_filebeat.sh [yamlファイル] [対象クラスタのユーザ名] [ 対象クラスタのkubectlサーバ] [対象クラスタのマスターノード]
```
**kubectlコマンド用サーバなしの場合のコマンド**
```
./delete_filebeat.sh [対象クラスタのユーザ名] [対象クラスタのマスターノード]
```

**シェルの中身**

```
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
```

**実行結果**

対象のVMの，Elasticsearchに接続するためのSecretとFilebeatのPod，それにelasticというネームスペースが削除される．
```
cdsl@logs-master:~/log_tool$ ./delete_filebeat.sh cdsl arita-master2
cdsl@arita-master2's password:
config                                  100% 2961    87.9KB/s   00:00
release "fb" uninstalled
NAME                READY   STATUS        RESTARTS   AGE
fb-filebeat-jfsbb   0/1     Terminating   0          34h
secret "elasticsearch-master-credentials" deleted
namespace "elastic" deleted
```

# 仕組み・注意点
ログサーバのkubectlコマンドのconfigファイルを，ログ収集対象のKubernetesクラスタのconfigファイルで一時的に書き換えている．
それにより，kubectlのコマンドで通信が行われるクラスタを一時的に変更することができる．
このシェルは，~/.kube/configのkubectl設定ファイルがあり，対象のVMのconfigファイルに読み込み権限がないと実行できません．

