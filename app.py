#!/usr/bin/env python3
import os
import aws_cdk as cdk
from three_tier_eks.three_tier_eks_stack import ThreeTierEksStack

app = cdk.App()

ThreeTierEksStack(app, "ThreeTierEksStack",
    env=cdk.Environment(
        account=os.getenv('CDK_DEFAULT_ACCOUNT'),
        region=os.getenv('CDK_DEFAULT_REGION')
    )
)

app.synth()
