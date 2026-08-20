#!/bin/bash

NODES=$(kubectl get nodes -o jsonpath='{.items[*].metadata.name}')
[ -z "$NODES" ] && echo "노드를 찾을 수 없습니다." && exit 1

for NODE in $NODES; do
  NODEGROUP=$(kubectl get node "$NODE" -o jsonpath='{.metadata.labels.eks\.amazonaws\.com/nodegroup}')
  
  echo "=================================================="
  echo "NodeGroup: ${NODEGROUP:-N/A (Non-EKS Managed Node)}"
  echo "=================================================="
  
  kubectl get pods -A --field-selector spec.nodeName="$NODE" -o wide
  echo ""
done