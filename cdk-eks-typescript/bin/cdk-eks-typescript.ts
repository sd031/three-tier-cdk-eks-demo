#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { CdkEksTypescriptStack } from '../lib/cdk-eks-typescript-stack';

const app = new cdk.App();
new CdkEksTypescriptStack(app, 'ThreeTierEksStack', {
  env: {
    account: process.env.CDK_DEFAULT_ACCOUNT,
    region: process.env.CDK_DEFAULT_REGION || 'us-west-2',
  },
});
