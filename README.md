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