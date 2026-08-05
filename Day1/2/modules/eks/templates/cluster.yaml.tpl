apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: wskorea26-cluster
  region: ap-northeast-2
  version: "1.35"

vpc:
  id: ${vpc_id}
  subnets:
    private:
      ap-northeast-2c: { id: ${priv_subnet_c_id} }
      ap-northeast-2d: { id: ${priv_subnet_d_id} }
  clusterEndpoints:
    privateAccess: true
    publicAccess: true

secretsEncryption:
  keyARN: ${eks_key_arn}

cloudWatch:
  clusterLogging:
    enableTypes: ["*"]

addonsConfig:
  autoApplyPodIdentityAssociations: false

addons:
  - name: vpc-cni
  - name: coredns
  - name: kube-proxy

iam:
  withOIDC: true

managedNodeGroups:
  - name: wskorea26-addon-ng
    amiFamily: AmazonLinux2023
    instanceType: t3.medium
    desiredCapacity: 2
    minSize: 2
    maxSize: 4
    privateNetworking: true
    subnets:
      - ${priv_subnet_c_id}
      - ${priv_subnet_d_id}
    securityGroups:
      attachIDs:
        - ${node_extra_sg_id}
    labels:
      node-type: addon
    tags:
      Name: wskorea26-addon-node
    propagateASGTags: true
    volumeSize: 20
    volumeType: gp3

  - name: wskorea26-app-ng
    amiFamily: AmazonLinux2023
    instanceType: t3.medium
    desiredCapacity: 2
    minSize: 2
    maxSize: 4
    privateNetworking: true
    subnets:
      - ${priv_subnet_c_id}
      - ${priv_subnet_d_id}
    securityGroups:
      attachIDs:
        - ${node_extra_sg_id}
    labels:
      node-type: app
    taints:
      - key: node-type
        value: app
        effect: NoSchedule
    tags:
      Name: wskorea26-app-node
    propagateASGTags: true
    volumeSize: 20
    volumeType: gp3
