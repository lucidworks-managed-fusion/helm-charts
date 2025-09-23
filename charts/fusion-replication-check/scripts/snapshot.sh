#!/bin/bash

# This script takes a "snapshot" of the current cluster state and records
# detailed information about the nodes, pods, it also collects operator logs
# and the current Solr cluster state.

if [ $# -eq 0 ]
then
  echo "Usage: ./snapshot <namespace>"
  exit -1
fi

#set -x

NAMESPACE=$1
if [ $# -gt 1 ] ; then
  DIR=$2
else
  DIR="snapshot_`TZ=UTC date '+%Y-%m-%d_%H-%M-%S'`"
fi

mkdir -p $DIR
echo "Collecting operator logs..."
kubectl logs -l app=solr-autoscaling-operator --tail=-1 --timestamps=true --prefix=true -n $NAMESPACE > $DIR/autoscaling-operator.log
kubectl logs -l control-plane=solr-operator --tail=-1 --timestamps=true --prefix=true -n $NAMESPACE > $DIR/solr-operator.log
OPERATOR_POD=`kubectl get pods -l app=solr-autoscaling-operator -n $NAMESPACE -o=name`
kubectl exec $OPERATOR_POD -n $NAMESPACE -- /usr/bin/wget -qO - "http://localhost:8080/status" > $DIR/autoscaling-operator-status.json
kubectl exec $OPERATOR_POD -n $NAMESPACE -- /usr/bin/wget -qO - "http://localhost:9090/metrics" > $DIR/autoscaling-operator-metrics.json
echo "Collecting pod logs..."
kubectl get pods -o=custom-columns=NAME:.metadata.name,STATUS:.status.phase,READY:.status.containerStatuses[0].ready,RESTARTS:.status.containerStatuses[0].restartCount,NODE:.spec.nodeName -n $NAMESPACE > $DIR/pods.log
kubectl describe pods -n $NAMESPACE > $DIR/pods-descr.log
echo "Collecting node / SolrCloud / SolrScaling information..."
kubectl get nodes -L type,topology.kubernetes.io/zone > $DIR/nodes.log
kubectl get nodes -o yaml > $DIR/nodes.yaml
kubectl get solrclouds -o yaml -n $NAMESPACE > $DIR/solrclouds.yaml
kubectl get solrscalings -o yaml -n $NAMESPACE > $DIR/solrscalings.yaml
kubectl get all -o yaml -n $NAMESPACE > $DIR/cluster.yaml

echo "Collecting PV / PVC / HPA / ConfigMap information..."
kubectl get pvc -o yaml -n $NAMESPACE > $DIR/pvcs.yaml
kubectl get pv -o yaml -n $NAMESPACE > $DIR/pvs.yaml

kubectl get hpa -o yaml -n $NAMESPACE > $DIR/hpas.yaml
kubectl get configmaps -o yaml -n $NAMESPACE > $DIR/configmaps.yaml

echo "Collecting Solr CLUSTERSTATUS..."
kubectl exec internal-standard-solrcloud-0 -n $NAMESPACE -c solrcloud-node -- /usr/bin/curl -s 'http://localhost:8983/solr/admin/collections?action=CLUSTERSTATUS' > $DIR/solr_clusterstatus.json

echo "Collecting Overseer logs..."
kubectl exec internal-standard-solrcloud-0 -n $NAMESPACE -c solrcloud-node -- /usr/bin/curl -s 'http://localhost:8983/solr/admin/collections?action=OVERSEERSTATUS' > $DIR/solr_overseerstatus.json
OVERSEER=`cat $DIR/solr_overseerstatus.json | jq -r '.leader' | cut -f 1 -d .`
kubectl logs $OVERSEER --tail=-1 -n $NAMESPACE > $DIR/solr_overseer.log

echo "Collecting logs from all Solr pods, may take a while..."

# SOLRS=`kubectl get pods -l technology=solr-cloud -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' -n $NAMESPACE`
# for i in $SOLRS
# do
#   echo " - $i"
#   mkdir $DIR/$i
#   kubectl cp $NAMESPACE/$i:/var/solr/logs $DIR/$i/ -c solrcloud-node --retries=3
# done
# ./get_solr_logs.sh -n $NAMESPACE -w $DIR

# zip -r $DIR.zip $DIR
# rm -r $DIR
