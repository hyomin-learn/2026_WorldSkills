# Notion URL
```
https://maddening-supernova-808.notion.site/Tech-Skills-3abe2d1e99b880afaf0ce0646ae5c9d1?source=copy_link
```

---

# Infra Setup
```shell
terraform init
```

```shell
terraform apply --auto-approve
```

---

# EKS Setup

## EKS Entry - Automatic 
```shell
USER_ARN=$(aws sts get-caller-identity --query "Arn" --output text)
REGION_CODE="<REGION_CODE>"
EKS_CLUSTER_NAME="<EKS_CLUSTER_NAME>"

aws eks create-access-entry --cluster-name $EKS_CLUSTER_NAME --principal-arn $USER_ARN --region $REGION_CODE > /dev/null
aws eks associate-access-policy --cluster-name $EKS_CLUSTER_NAME --principal-arn $USER_ARN --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy --access-scope type=cluster --region $REGION_CODE > /dev/null
```

<br>

## EKS Entry - Passivity
```shell
REGION_CODE="<REGION_CODE>"
EKS_CLUSTER_NAME="<EKS_CLUSTER_NAME>"
USER_ARN=$(aws sts get-caller-identity --query Arn --output text)

aws eks create-access-entry --cluster-name $EKS_CLUSTER_NAME --principal-arn $USER_ARN --type STANDARD --region $REGION_CODE
aws eks associate-access-policy --cluster-name $EKS_CLUSTER_NAM --principal-arn $USER_ARN --access-scope type=cluster --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy --region $REGION_CODE
```

<br>

## EKS Kubeconfig
```shell
REGION_CODE="<REGION_CODE>"
EKS_CLUSTER_NAME="<EKS_CLUSTER_NAME>"

aws eks update-kubeconfig --region $REGION_CODE --name $EKS_CLUSTER_NAME
source kubectl-connect $EKS_CLUSTER_NAME
```
<br>

## EKS Kubeconfig version2
```shell
aws eks update-kubeconfig --region $REGION_CODE --name $EKS_CLUSTER_NAME
export KUBECONFIG=~/.kube/config
cp ~/.kube/config /home/cloudshell-user/.kube/config-클러스터 이름
kubectl get nodes 
source kubectl-connect $EKS_CLUSTER_NAME -> 확인되면 채점
```

