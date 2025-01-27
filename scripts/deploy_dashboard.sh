#!/usr/bin/env bash
set -e

export AWS_DEFAULT_REGION=$(cat sandbox.auto.tfvars.json | jq -r .aws_region)
export AWS_ASSUME_ROLE=$(cat sandbox.auto.tfvars.json | jq -r .assume_role)
export AWS_ACCOUNT_ID=$(cat sandbox.auto.tfvars.json | jq -r .account_id)

echo "debug:"
echo "AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION"
echo "AWS_ASSUME_ROLE=$AWS_ASSUME_ROLE"
echo "AWS_ACCOUNT_ID=$AWS_ACCOUNT_ID"
echo "AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID:0:5}"

aws sts assume-role --output json --role-arn arn:aws:iam::$AWS_ACCOUNT_ID:role/$AWS_ASSUME_ROLE --role-session-name eks-configuration-test > credentials

export AWS_ACCESS_KEY_ID=$(cat credentials | jq -r ".Credentials.AccessKeyId")
export AWS_SECRET_ACCESS_KEY=$(cat credentials | jq -r ".Credentials.SecretAccessKey")
export AWS_SESSION_TOKEN=$(cat credentials | jq -r ".Credentials.SessionToken")

# current versions table
export TABLE="| dependency | sandbox | preview |\\\\n|----|----|----|\\\\n"
export EKS_VERSIONS="| eks |"
export AMI_VERSIONS="| ami |"
export COREDNS_VERSIONS="| coredns |"
export KUBE_PROXY_VERSIONS="| kube-proxy |"
export VPC_CNI_VERSIONS="| vpc-cni |"
export EBS_CSI_VERSIONS="| ebs-csi |"

declare -a clusters=(sandbox preview)

echo "generate markdown table with the desired versions of the services managed by the lab-platform-eks-base pipeline for all clusters"
for cluster in "${clusters[@]}";
do
  # append environment EKS version
  export EKS_VERSION=$(cat environments/$cluster.auto.tfvars.json.tpl | jq -r .cluster_version)
  export DESIRED_CLUSTER_VERSION=$EKS_VERSION
  export EKS_VERSIONS="$EKS_VERSIONS $EKS_VERSION |"

  # append environment AMI version
  export CLUSTER_NODES=$(aws ec2 describe-instances --filter "Name=tag:kubernetes.io/cluster/$cluster,Values=owned")
  export CURRENT_AMI_VERSION=$(echo $CLUSTER_NODES | jq -r '.Reservations | .[0] | .Instances | .[0] | .ImageId')
  echo "CURRENT_AMI_VERSION=$CURRENT_AMI_VERSION"
  export AMI_VERSIONS="$AMI_VERSIONS $CURRENT_AMI_VERSION |"

  # append environment coreDNS version
  export DESIRED_COREDNS_VERSION=$(cat environments/$cluster.auto.tfvars.json.tpl | jq -r .coredns_version)
  export COREDNS_VERSIONS="$COREDNS_VERSIONS $DESIRED_COREDNS_VERSION |"

  # append environment kube-proxy version
  export DESIRED_KUBE_PROXY_VERSION=$(cat environments/$cluster.auto.tfvars.json.tpl | jq -r .kube_proxy_version)
  export KUBE_PROXY_VERSIONS="$KUBE_PROXY_VERSIONS $DESIRED_KUBE_PROXY_VERSION |"

  # append environment VPC-CNI version
  export DESIRED_VPC_CNI_VERSION=$(cat environments/$cluster.auto.tfvars.json.tpl | jq -r .vpc_cni_version)
  export VPC_CNI_VERSIONS="$VPC_CNI_VERSIONS $DESIRED_VPC_CNI_VERSION |"

  # append environment EBS-CSI version
  export DESIRED_EBS_CSI_VERSION=$(cat environments/$cluster.auto.tfvars.json.tpl | jq -r .aws_ebs_csi_version)
  export EBS_CSI_VERSIONS="$EBS_CSI_VERSIONS $DESIRED_EBS_CSI_VERSION |"

done

# assumeble markdown table
export CURRENT_TABLE="$TABLE$EKS_VERSIONS\\\\n$AMI_VERSIONS\\\\n$COREDNS_VERSIONS\\\\n$KUBE_PROXY_VERSIONS\\\\n$VPC_CNI_VERSIONS\\\\n$EBS_CSI_VERSIONS\\\\n"

# current versions table
declare TABLE="| available |\\\\n|----|\\\\n"
declare EKS_VERSIONS="| - |"
declare AMI_VERSIONS="|"
declare COREDNS_VERSIONS="|"
declare KUBE_PROXY_VERSIONS="|"
declare VPC_CNI_VERSIONS="|"
declare EBS_CSI_VERSIONS="|"

echo "generate markdown table with the available versions of the services managed by the lab-platform-eks-base pipeline for all clusters"

# fetch the current ami release versions available. Use this for al2= /aws/service/eks/optimized-ami/$DESIRED_CLUSTER_VERSION/amazon-linux-2/recommended/image_id 
export LATEST_AMI_VERSION=$(aws ssm get-parameter --name /aws/service/bottlerocket/aws-k8s-$DESIRED_CLUSTER_VERSION/x86_64/latest/image_id --region $AWS_DEFAULT_REGION | jq -r '.Parameter.Value')
export AMI_VERSIONS="$AMI_VERSIONS $LATEST_AMI_VERSION |"

export AVAILABLE_ADDON_VERSIONS=$(aws eks describe-addon-versions)

# fetch the current coredns version available
export LATEST_COREDNS_VERSION=$(echo $AVAILABLE_ADDON_VERSIONS | jq -r '.addons[] | select(.addonName=="coredns") | .addonVersions[0] | .addonVersion')
export COREDNS_VERSIONS="$COREDNS_VERSIONS $LATEST_COREDNS_VERSION |"

# fetch the current kube-proxy version available
export LATEST_KUBE_PROXY_VERSION=$(echo $AVAILABLE_ADDON_VERSIONS | jq -r '.addons[] | select(.addonName=="kube-proxy") | .addonVersions[0] | .addonVersion')
export KUBE_PROXY_VERSIONS="$KUBE_PROXY_VERSIONS $LATEST_KUBE_PROXY_VERSION |"

# fetch the current vpc-cni version available
export LATEST_VPC_CNI_VERSION=$(echo $AVAILABLE_ADDON_VERSIONS | jq -r '.addons[] | select(.addonName=="vpc-cni") | .addonVersions[0] | .addonVersion')
export VPC_CNI_VERSIONS="$VPC_CNI_VERSIONS $LATEST_VPC_CNI_VERSION |"

# fetch the current ebs-csi version available
export LATEST_EBS_CSI_VERSION=$(echo $AVAILABLE_ADDON_VERSIONS | jq -r '.addons[] | select(.addonName=="aws-ebs-csi-driver") | .addonVersions[0] | .addonVersion')
export EBS_CSI_VERSIONS="$EBS_CSI_VERSIONS $LATEST_EBS_CSI_VERSION |"

# assumeble markdown table
export LATEST_TABLE="$TABLE$EKS_VERSIONS\\\\n$AMI_VERSIONS\\\\n$COREDNS_VERSIONS\\\\n$KUBE_PROXY_VERSIONS\\\\n$VPC_CNI_VERSIONS\\\\n$EBS_CSI_VERSIONS\\\\n"

echo "check production current versions against latest"
export TABLE_COLOR="green"
export ALERT_TABLE_COLOR="pink"

if [[ $CURRENT_AMI_VERSION != $LATEST_AMI_VERSION ]]; then
  export TABLE_COLOR=$ALERT_TABLE_COLOR
fi
if [[ $DESIRED_COREDNS_VERSION != $LATEST_COREDNS_VERSION ]]; then
  export TABLE_COLOR=$ALERT_TABLE_COLOR
fi
if [[ $DESIRED_KUBE_PROXY_VERSION != $LATEST_KUBE_PROXY_VERSION ]]; then
  export TABLE_COLOR=$ALERT_TABLE_COLOR
fi
if [[ $DESIRED_VPC_CNI_VERSION != $LATEST_VPC_CNI_VERSION ]]; then
  export TABLE_COLOR=$ALERT_TABLE_COLOR
fi
if [[ $DESIRED_EBS_CSI_VERSION != $LATEST_EBS_CSI_VERSION ]]; then
  export TABLE_COLOR=$ALERT_TABLE_COLOR
fi

echo "insert markdown into dashboard.json"
cp tpl/dashboard.json.tpl observe/dashboard.json

if [[ $(uname) == "Darwin" ]]; then
  gsed -i "s/CURRENT_TABLE/$CURRENT_TABLE/g" observe/dashboard.json
  gsed -i "s/LATEST_TABLE/$LATEST_TABLE/g" observe/dashboard.json
  gsed -i "s/TABLE_COLOR/$TABLE_COLOR/g" observe/dashboard.json
else 
  sed -i "s/CURRENT_TABLE/$CURRENT_TABLE/g" observe/dashboard.json
  sed -i "s/LATEST_TABLE/$LATEST_TABLE/g" observe/dashboard.json
  sed -i "s/TABLE_COLOR/$TABLE_COLOR/g" observe/dashboard.json
fi

python scripts/dashboard.py