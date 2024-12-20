# 概要
ログサーバから，kubernetesクラスタのVMのログを収集するためには，その収集対象のkubernetesクラスタにFilebeatを作成し，ログを送る必要があります．
しかし，Kubernetesとhelmを使いFilebeatを作成するとき，収集対象のkubernetesクラスタにもhelmをインストールしたり，yamlファイルを送る必要があり，少々手間がかかります．
そこで，Kubernetes環境と元となるyamlファイルさえあれば，ログサーバからkubernetesクラスタにFilebeatを作成してくれるシェルを組みました．

# 環境
実行した環境は以下の通りです

**ログサーバ**

* Ubuntu 24.04.1
* k3s：v1.30.5+k3s1
* helm：v3.16.1

**ログ収集対象のサーバ**

* Ubuntu 24.04.1
* k3s：v1.30.5+k3s1

# 使い方
FIlebeatを作成してくれるcreate/_filebeat.shと，シェルで作成したFilebeatを>削除してくれるdelete/_filebeat.shがある．

## Filebeatを作成

kubectlコマンドを打つためのサーバとmasterノードを分離している場合と，分離していない場合で必要な引数の数がひとつ変わります.
また，elasticsearchのユーザ名とパスワードを入力するべきところがあるので，シェルに直接入力してください

**kubectlコマンド用サーバありの場合の実行コマンド**
```
./create_filebeat.sh [yamlファイル] [対象クラスタのユーザ名] [ 対象クラスタのkubectlサーバ] [対象クラスタのマスターノード]
```
**kubectlコマンド用サーバなしの場合の実行コマンド**
```
./create_filebeat.sh [yamlファイル] [対象クラスタのユーザ名] [対象クラスタのマスターノード]
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

**kubectlコマンド用サーバありの場合の実行コマンド**
```
./delete_filebeat.sh [yamlファイル] [対象クラスタのユーザ名] [ 対象クラスタのkubectlサーバ] [対象クラスタのマスターノード]
```
**kubectlコマンド用サーバなしの場合の実行コマンド**
```
./delete_filebeat.sh [対象クラスタのユーザ名] [対象クラスタのマスターノード]
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

