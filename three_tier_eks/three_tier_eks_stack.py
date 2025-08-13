from aws_cdk import (
    Stack,
    aws_ec2 as ec2,
    aws_eks as eks,
    aws_iam as iam,
    aws_rds as rds,
    aws_secretsmanager as secretsmanager,
    CfnOutput,
    RemovalPolicy,
)
from constructs import Construct


class ThreeTierEksStack(Stack):

    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # Create VPC with public and private subnets across 3 AZs
        vpc = ec2.Vpc(
            self, "ThreeTierVPC",
            max_azs=3,
            nat_gateways=2,
            subnet_configuration=[
                ec2.SubnetConfiguration(
                    name="public",
                    subnet_type=ec2.SubnetType.PUBLIC,
                    cidr_mask=24
                ),
                ec2.SubnetConfiguration(
                    name="private",
                    subnet_type=ec2.SubnetType.PRIVATE_WITH_EGRESS,
                    cidr_mask=24
                ),
                ec2.SubnetConfiguration(
                    name="database",
                    subnet_type=ec2.SubnetType.PRIVATE_ISOLATED,
                    cidr_mask=24
                )
            ]
        )

        # Create EKS Auto Mode Cluster
        # EKS Auto Mode automatically manages compute, networking, and storage
        cluster = eks.Cluster(
            self, "ThreeTierCluster",
            version=eks.KubernetesVersion.V1_30,
            vpc=vpc,
            default_capacity=0,
            endpoint_access=eks.EndpointAccess.PUBLIC_AND_PRIVATE,
            vpc_subnets=[ec2.SubnetSelection(subnet_type=ec2.SubnetType.PRIVATE_WITH_EGRESS)],
            cluster_logging=[
                eks.ClusterLoggingTypes.API,
                eks.ClusterLoggingTypes.AUDIT,
                eks.ClusterLoggingTypes.AUTHENTICATOR,
                eks.ClusterLoggingTypes.CONTROLLER_MANAGER,
                eks.ClusterLoggingTypes.SCHEDULER
            ]
        )

        # Add EKS Auto Mode configuration using CfnCluster
        # This enables automatic compute capacity management
        cfn_cluster = cluster.node.default_child
        cfn_cluster.add_property_override("ComputeConfig", {
            "Enabled": True,
            "NodePools": [
                {
                    "Name": "system",
                    "InstanceTypes": ["m5.large", "m5.xlarge", "m4.large"],
                    "ScalingConfig": {
                        "MinSize": 0,
                        "MaxSize": 1000,
                        "DesiredSize": 2
                    },
                    "UpdateConfig": {
                        "MaxUnavailablePercentage": 25
                    }
                }
            ]
        })

        # Enable EKS Auto Mode storage configuration
        cfn_cluster.add_property_override("StorageConfig", {
            "BlockStorage": {
                "Enabled": True
            }
        })

        # EKS Auto Mode handles node provisioning automatically
        # No manual node groups needed

        # Create security group for RDS
        db_security_group = ec2.SecurityGroup(
            self, "DatabaseSecurityGroup",
            vpc=vpc,
            description="Security group for RDS PostgreSQL database",
            allow_all_outbound=False
        )

        # Allow PostgreSQL access from EKS nodes
        db_security_group.add_ingress_rule(
            peer=ec2.Peer.ipv4(vpc.vpc_cidr_block),
            connection=ec2.Port.tcp(5432),
            description="Allow PostgreSQL access from VPC"
        )

        # Create RDS subnet group
        db_subnet_group = rds.SubnetGroup(
            self, "DatabaseSubnetGroup",
            description="Subnet group for RDS database",
            vpc=vpc,
            vpc_subnets=ec2.SubnetSelection(subnet_type=ec2.SubnetType.PRIVATE_ISOLATED)
        )

        # Create RDS PostgreSQL database
        database = rds.DatabaseInstance(
            self, "PostgreSQLDatabase",
            engine=rds.DatabaseInstanceEngine.postgres(
                version=rds.PostgresEngineVersion.VER_15_3
            ),
            instance_type=ec2.InstanceType.of(ec2.InstanceClass.T3, ec2.InstanceSize.MICRO),
            credentials=rds.Credentials.from_generated_secret("dbadmin"),
            vpc=vpc,
            subnet_group=db_subnet_group,
            security_groups=[db_security_group],
            database_name="threetierdb",
            backup_retention=rds.BackupProps(retention=7),
            deletion_protection=False,
            removal_policy=RemovalPolicy.DESTROY
        )

        # Create AWS Load Balancer Controller service account
        alb_service_account = cluster.add_service_account(
            "ALBServiceAccount",
            name="aws-load-balancer-controller",
            namespace="kube-system"
        )

        # Add AWS Load Balancer Controller policy
        alb_service_account.add_to_principal_policy(
            iam.PolicyStatement(
                effect=iam.Effect.ALLOW,
                actions=[
                    "iam:CreateServiceLinkedRole",
                    "ec2:DescribeAccountAttributes",
                    "ec2:DescribeAddresses",
                    "ec2:DescribeAvailabilityZones",
                    "ec2:DescribeInternetGateways",
                    "ec2:DescribeVpcs",
                    "ec2:DescribeSubnets",
                    "ec2:DescribeSecurityGroups",
                    "ec2:DescribeInstances",
                    "ec2:DescribeNetworkInterfaces",
                    "ec2:DescribeTags",
                    "ec2:GetCoipPoolUsage",
                    "ec2:DescribeCoipPools",
                    "elasticloadbalancing:DescribeLoadBalancers",
                    "elasticloadbalancing:DescribeLoadBalancerAttributes",
                    "elasticloadbalancing:DescribeListeners",
                    "elasticloadbalancing:DescribeListenerCertificates",
                    "elasticloadbalancing:DescribeSSLPolicies",
                    "elasticloadbalancing:DescribeRules",
                    "elasticloadbalancing:DescribeTargetGroups",
                    "elasticloadbalancing:DescribeTargetGroupAttributes",
                    "elasticloadbalancing:DescribeTargetHealth",
                    "elasticloadbalancing:DescribeTags"
                ],
                resources=["*"]
            )
        )

        alb_service_account.add_to_principal_policy(
            iam.PolicyStatement(
                effect=iam.Effect.ALLOW,
                actions=[
                    "cognito-idp:DescribeUserPoolClient",
                    "acm:ListCertificates",
                    "acm:DescribeCertificate",
                    "iam:ListServerCertificates",
                    "iam:GetServerCertificate",
                    "waf-regional:GetWebACL",
                    "waf-regional:GetWebACLForResource",
                    "waf-regional:AssociateWebACL",
                    "waf-regional:DisassociateWebACL",
                    "wafv2:GetWebACL",
                    "wafv2:GetWebACLForResource",
                    "wafv2:AssociateWebACL",
                    "wafv2:DisassociateWebACL",
                    "shield:DescribeProtection",
                    "shield:GetSubscriptionState",
                    "shield:DescribeSubscription",
                    "shield:CreateProtection",
                    "shield:DeleteProtection"
                ],
                resources=["*"]
            )
        )

        alb_service_account.add_to_principal_policy(
            iam.PolicyStatement(
                effect=iam.Effect.ALLOW,
                actions=[
                    "ec2:AuthorizeSecurityGroupIngress",
                    "ec2:RevokeSecurityGroupIngress",
                    "ec2:CreateSecurityGroup",
                    "elasticloadbalancing:CreateListener",
                    "elasticloadbalancing:DeleteListener",
                    "elasticloadbalancing:CreateRule",
                    "elasticloadbalancing:DeleteRule",
                    "elasticloadbalancing:SetWebAcl",
                    "elasticloadbalancing:ModifyListener",
                    "elasticloadbalancing:AddListenerCertificates",
                    "elasticloadbalancing:RemoveListenerCertificates",
                    "elasticloadbalancing:ModifyRule"
                ],
                resources=["*"]
            )
        )

        alb_service_account.add_to_principal_policy(
            iam.PolicyStatement(
                effect=iam.Effect.ALLOW,
                actions=[
                    "elasticloadbalancing:CreateLoadBalancer",
                    "elasticloadbalancing:CreateTargetGroup"
                ],
                resources=["*"],
                conditions={
                    "Null": {
                        "aws:RequestedRegion": "false"
                    }
                }
            )
        )

        alb_service_account.add_to_principal_policy(
            iam.PolicyStatement(
                effect=iam.Effect.ALLOW,
                actions=[
                    "elasticloadbalancing:CreateLoadBalancer",
                    "elasticloadbalancing:CreateTargetGroup",
                    "elasticloadbalancing:DeleteLoadBalancer",
                    "elasticloadbalancing:DeleteTargetGroup",
                    "elasticloadbalancing:ModifyLoadBalancerAttributes",
                    "elasticloadbalancing:ModifyTargetGroup",
                    "elasticloadbalancing:ModifyTargetGroupAttributes",
                    "elasticloadbalancing:RegisterTargets",
                    "elasticloadbalancing:DeregisterTargets",
                    "elasticloadbalancing:SetIpAddressType",
                    "elasticloadbalancing:SetSecurityGroups",
                    "elasticloadbalancing:SetSubnets",
                    "elasticloadbalancing:DeleteLoadBalancer",
                    "elasticloadbalancing:DeleteTargetGroup",
                    "elasticloadbalancing:AddTags",
                    "elasticloadbalancing:RemoveTags"
                ],
                resources=["*"],
                conditions={
                    "Null": {
                        "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
                    }
                }
            )
        )

        alb_service_account.add_to_principal_policy(
            iam.PolicyStatement(
                effect=iam.Effect.ALLOW,
                actions=[
                    "ec2:CreateTags"
                ],
                resources=["arn:aws:ec2:*:*:security-group/*"],
                conditions={
                    "StringEquals": {
                        "ec2:CreateAction": "CreateSecurityGroup"
                    },
                    "Null": {
                        "aws:RequestedRegion": "false"
                    }
                }
            )
        )

        alb_service_account.add_to_principal_policy(
            iam.PolicyStatement(
                effect=iam.Effect.ALLOW,
                actions=[
                    "ec2:CreateTags",
                    "ec2:DeleteTags"
                ],
                resources=["arn:aws:ec2:*:*:security-group/*"],
                conditions={
                    "Null": {
                        "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
                    }
                }
            )
        )

        alb_service_account.add_to_principal_policy(
            iam.PolicyStatement(
                effect=iam.Effect.ALLOW,
                actions=[
                    "ec2:AuthorizeSecurityGroupIngress",
                    "ec2:RevokeSecurityGroupIngress",
                    "ec2:DeleteSecurityGroup"
                ],
                resources=["*"],
                conditions={
                    "Null": {
                        "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
                    }
                }
            )
        )

        alb_service_account.add_to_principal_policy(
            iam.PolicyStatement(
                effect=iam.Effect.ALLOW,
                actions=[
                    "elasticloadbalancing:AddTags",
                    "elasticloadbalancing:RemoveTags"
                ],
                resources=[
                    "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
                    "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
                    "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
                ],
                conditions={
                    "Null": {
                        "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
                    }
                }
            )
        )

        alb_service_account.add_to_principal_policy(
            iam.PolicyStatement(
                effect=iam.Effect.ALLOW,
                actions=[
                    "elasticloadbalancing:AddTags",
                    "elasticloadbalancing:RemoveTags"
                ],
                resources=[
                    "arn:aws:elasticloadbalancing:*:*:listener/net/*/*/*",
                    "arn:aws:elasticloadbalancing:*:*:listener/app/*/*/*",
                    "arn:aws:elasticloadbalancing:*:*:listener-rule/net/*/*/*",
                    "arn:aws:elasticloadbalancing:*:*:listener-rule/app/*/*/*"
                ]
            )
        )

        # Outputs
        CfnOutput(
            self, "ClusterName",
            value=cluster.cluster_name,
            description="EKS Cluster Name"
        )

        CfnOutput(
            self, "DatabaseEndpoint",
            value=database.instance_endpoint.hostname,
            description="RDS Database Endpoint"
        )

        CfnOutput(
            self, "DatabaseSecretArn",
            value=database.secret.secret_arn,
            description="RDS Database Secret ARN"
        )

        CfnOutput(
            self, "VpcId",
            value=vpc.vpc_id,
            description="VPC ID"
        )
