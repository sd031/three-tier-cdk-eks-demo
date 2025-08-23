import * as cdk from 'aws-cdk-lib';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as eks from 'aws-cdk-lib/aws-eks';
import * as eksv2 from '@aws-cdk/aws-eks-v2-alpha';
import { KubectlV32Layer } from '@aws-cdk/lambda-layer-kubectl-v32';
import { Construct } from 'constructs';

export class CdkEksTypescriptStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // Create VPC with public and private subnets across 3 AZs
    const vpc = new ec2.Vpc(this, 'ThreeTierVPC', {
      maxAzs: 3,
      natGateways: 2,
      subnetConfiguration: [
        {
          name: 'public',
          subnetType: ec2.SubnetType.PUBLIC,
          cidrMask: 24
        },
        {
          name: 'private',
          subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS,
          cidrMask: 24
        },
        {
          name: 'database',
          subnetType: ec2.SubnetType.PRIVATE_ISOLATED,
          cidrMask: 24
        }
      ]
    });

    // Get current AWS account and region for root account access
    const account = cdk.Stack.of(this).account;
    const region = cdk.Stack.of(this).region;

    // Create IAM Role for cluster admin access (root account)
    const clusterAdminRole = new iam.Role(this, 'ClusterAdminRole', {
      assumedBy: new iam.ArnPrincipal(`arn:aws:iam::${account}:root`),
      description: 'EKS Cluster Admin Role for root account access'
    });

    // Create EKS Cluster with Auto Mode and Kubernetes v1.32
    const eksCluster = new eksv2.Cluster(this, 'ThreeTierCluster', {
      version: eksv2.KubernetesVersion.V1_32,
      defaultCapacityType: eksv2.DefaultCapacityType.AUTOMODE,
      vpc: vpc,
      vpcSubnets: [{ subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS }],
      compute: {
        nodePools: ['system', 'general-purpose'],
      },
      kubectlProviderOptions: {
        kubectlLayer: new KubectlV32Layer(this, 'KubectlLayer')
      },
    });

    // Grant cluster admin access to root account
    eksCluster.grantAccess('clusterAdminAccess', clusterAdminRole.roleArn, [
      eks.AccessPolicy.fromAccessPolicyName('AmazonEKSClusterAdminPolicy', {
        accessScopeType: eks.AccessScopeType.CLUSTER,
      }),
    ]);

    // Create AWS Load Balancer Controller service account
    const albServiceAccount = eksCluster.addServiceAccount('ALBServiceAccount', {
      name: 'aws-load-balancer-controller',
      namespace: 'kube-system'
    });

    // Add AWS Load Balancer Controller policies
    albServiceAccount.addToPrincipalPolicy(new iam.PolicyStatement({
      effect: iam.Effect.ALLOW,
      actions: [
        'iam:CreateServiceLinkedRole',
        'ec2:DescribeAccountAttributes',
        'ec2:DescribeAddresses',
        'ec2:DescribeAvailabilityZones',
        'ec2:DescribeInternetGateways',
        'ec2:DescribeVpcs',
        'ec2:DescribeSubnets',
        'ec2:DescribeSecurityGroups',
        'ec2:DescribeInstances',
        'ec2:DescribeNetworkInterfaces',
        'ec2:DescribeTags',
        'ec2:GetCoipPoolUsage',
        'ec2:DescribeCoipPools',
        'elasticloadbalancing:DescribeLoadBalancers',
        'elasticloadbalancing:DescribeLoadBalancerAttributes',
        'elasticloadbalancing:DescribeListeners',
        'elasticloadbalancing:DescribeListenerCertificates',
        'elasticloadbalancing:DescribeSSLPolicies',
        'elasticloadbalancing:DescribeRules',
        'elasticloadbalancing:DescribeTargetGroups',
        'elasticloadbalancing:DescribeTargetGroupAttributes',
        'elasticloadbalancing:DescribeTargetHealth',
        'elasticloadbalancing:DescribeTags'
      ],
      resources: ['*']
    }));

    albServiceAccount.addToPrincipalPolicy(new iam.PolicyStatement({
      effect: iam.Effect.ALLOW,
      actions: [
        'cognito-idp:DescribeUserPoolClient',
        'acm:ListCertificates',
        'acm:DescribeCertificate',
        'iam:ListServerCertificates',
        'iam:GetServerCertificate',
        'waf-regional:GetWebACL',
        'waf-regional:GetWebACLForResource',
        'waf-regional:AssociateWebACL',
        'waf-regional:DisassociateWebACL',
        'wafv2:GetWebACL',
        'wafv2:GetWebACLForResource',
        'wafv2:AssociateWebACL',
        'wafv2:DisassociateWebACL',
        'shield:DescribeProtection',
        'shield:GetSubscriptionState',
        'shield:DescribeSubscription',
        'shield:CreateProtection',
        'shield:DeleteProtection'
      ],
      resources: ['*']
    }));

    albServiceAccount.addToPrincipalPolicy(new iam.PolicyStatement({
      effect: iam.Effect.ALLOW,
      actions: [
        'ec2:AuthorizeSecurityGroupIngress',
        'ec2:RevokeSecurityGroupIngress',
        'ec2:CreateSecurityGroup',
        'elasticloadbalancing:CreateListener',
        'elasticloadbalancing:DeleteListener',
        'elasticloadbalancing:CreateRule',
        'elasticloadbalancing:DeleteRule',
        'elasticloadbalancing:SetWebAcl',
        'elasticloadbalancing:ModifyListener',
        'elasticloadbalancing:AddListenerCertificates',
        'elasticloadbalancing:RemoveListenerCertificates',
        'elasticloadbalancing:ModifyRule'
      ],
      resources: ['*']
    }));

    albServiceAccount.addToPrincipalPolicy(new iam.PolicyStatement({
      effect: iam.Effect.ALLOW,
      actions: [
        'elasticloadbalancing:CreateLoadBalancer',
        'elasticloadbalancing:CreateTargetGroup'
      ],
      resources: ['*'],
      conditions: {
        'Null': {
          'aws:RequestedRegion': 'false'
        }
      }
    }));

    albServiceAccount.addToPrincipalPolicy(new iam.PolicyStatement({
      effect: iam.Effect.ALLOW,
      actions: [
        'elasticloadbalancing:CreateLoadBalancer',
        'elasticloadbalancing:CreateTargetGroup',
        'elasticloadbalancing:DeleteLoadBalancer',
        'elasticloadbalancing:DeleteTargetGroup',
        'elasticloadbalancing:ModifyLoadBalancerAttributes',
        'elasticloadbalancing:ModifyTargetGroup',
        'elasticloadbalancing:ModifyTargetGroupAttributes',
        'elasticloadbalancing:RegisterTargets',
        'elasticloadbalancing:DeregisterTargets',
        'elasticloadbalancing:SetIpAddressType',
        'elasticloadbalancing:SetSecurityGroups',
        'elasticloadbalancing:SetSubnets',
        'elasticloadbalancing:DeleteLoadBalancer',
        'elasticloadbalancing:DeleteTargetGroup',
        'elasticloadbalancing:AddTags',
        'elasticloadbalancing:RemoveTags'
      ],
      resources: ['*'],
      conditions: {
        'Null': {
          'aws:ResourceTag/elbv2.k8s.aws/cluster': 'false'
        }
      }
    }));

    albServiceAccount.addToPrincipalPolicy(new iam.PolicyStatement({
      effect: iam.Effect.ALLOW,
      actions: ['ec2:CreateTags'],
      resources: ['arn:aws:ec2:*:*:security-group/*'],
      conditions: {
        'StringEquals': {
          'ec2:CreateAction': 'CreateSecurityGroup'
        },
        'Null': {
          'aws:RequestedRegion': 'false'
        }
      }
    }));

    albServiceAccount.addToPrincipalPolicy(new iam.PolicyStatement({
      effect: iam.Effect.ALLOW,
      actions: ['ec2:CreateTags', 'ec2:DeleteTags'],
      resources: ['arn:aws:ec2:*:*:security-group/*'],
      conditions: {
        'Null': {
          'aws:ResourceTag/elbv2.k8s.aws/cluster': 'false'
        }
      }
    }));

    albServiceAccount.addToPrincipalPolicy(new iam.PolicyStatement({
      effect: iam.Effect.ALLOW,
      actions: [
        'ec2:AuthorizeSecurityGroupIngress',
        'ec2:RevokeSecurityGroupIngress',
        'ec2:DeleteSecurityGroup'
      ],
      resources: ['*'],
      conditions: {
        'Null': {
          'aws:ResourceTag/elbv2.k8s.aws/cluster': 'false'
        }
      }
    }));

    albServiceAccount.addToPrincipalPolicy(new iam.PolicyStatement({
      effect: iam.Effect.ALLOW,
      actions: ['elasticloadbalancing:AddTags', 'elasticloadbalancing:RemoveTags'],
      resources: [
        'arn:aws:elasticloadbalancing:*:*:targetgroup/*/*',
        'arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*',
        'arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*'
      ],
      conditions: {
        'Null': {
          'aws:ResourceTag/elbv2.k8s.aws/cluster': 'false'
        }
      }
    }));

    albServiceAccount.addToPrincipalPolicy(new iam.PolicyStatement({
      effect: iam.Effect.ALLOW,
      actions: ['elasticloadbalancing:AddTags', 'elasticloadbalancing:RemoveTags'],
      resources: [
        'arn:aws:elasticloadbalancing:*:*:listener/net/*/*/*',
        'arn:aws:elasticloadbalancing:*:*:listener/app/*/*/*',
        'arn:aws:elasticloadbalancing:*:*:listener-rule/net/*/*/*',
        'arn:aws:elasticloadbalancing:*:*:listener-rule/app/*/*/*'
      ]
    }));

    // Outputs
    new cdk.CfnOutput(this, 'ClusterName', {
      value: eksCluster.clusterName,
      description: 'EKS Cluster Name'
    });

    new cdk.CfnOutput(this, 'ClusterEndpoint', {
      value: eksCluster.clusterEndpoint,
      description: 'EKS Cluster Endpoint'
    });

    new cdk.CfnOutput(this, 'ClusterArn', {
      value: eksCluster.clusterArn,
      description: 'EKS Cluster ARN'
    });

    new cdk.CfnOutput(this, 'VpcId', {
      value: vpc.vpcId,
      description: 'VPC ID'
    });

    new cdk.CfnOutput(this, 'ClusterAdminRoleArn', {
      value: clusterAdminRole.roleArn,
      description: 'Cluster Admin Role ARN for root account access'
    });
  }
}
