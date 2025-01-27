{
    "aws_region": "us-east-2",
    "assume_role": "DPSTerraformRole",
    "account_id": "{{ twdps/di/svc/aws/dps-2/aws-account-id }}",

    "cluster_name": "sandbox",
    "cluster_version": "1.21",
    "vpc_cni_version": "v1.10.1-eksbuild.1",
    "coredns_version": "v1.8.4-eksbuild.1",
    "kube_proxy_version": "v1.21.2-eksbuild.2",
    "aws_ebs_csi_version": "v1.4.0-eksbuild.preview",

    "default_node_group_ami_type": "BOTTLEROCKET_x86_64",
    "default_node_group_platform": "bottlerocket",
    "default_node_group_min_size": "3",
    "default_node_group_max_size": "5",
    "default_node_group_desired_size": "3",
    "default_node_group_disk_size": "50",
    "default_node_group_capacity_type": "ON_DEMAND",
    "default_node_group_instance_types": ["m5.xlarge"]
}

