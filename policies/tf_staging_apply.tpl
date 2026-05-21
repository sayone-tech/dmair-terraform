{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "StateBucketRead",
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:ListBucket"],
      "Resource": [
        "${state_bucket_arn}",
        "${state_bucket_arn}/*"
      ]
    },
    {
      "Sid": "StateLockfileRw",
      "Effect": "Allow",
      "Action": ["s3:PutObject", "s3:DeleteObject"],
      "Resource": "${state_bucket_arn}/*.tflock"
    },
    {
      "Sid": "DescribeAllForRefresh",
      "Effect": "Allow",
      "Action": [
        "ec2:Describe*",
        "ec2:Get*",
        "rds:Describe*",
        "rds:ListTagsForResource",
        "ecr:Describe*",
        "ecr:List*",
        "ecr:Get*",
        "ecr:BatchGetImage",
        "secretsmanager:Describe*",
        "secretsmanager:ListSecret*",
        "secretsmanager:GetResourcePolicy",
        "iam:Get*",
        "iam:List*",
        "cloudfront:Get*",
        "cloudfront:List*",
        "s3:GetBucket*",
        "s3:GetEncryptionConfiguration",
        "s3:GetLifecycleConfiguration",
        "s3:GetObjectTagging",
        "s3:ListAllMyBuckets",
        "logs:Describe*",
        "logs:List*",
        "ssm:Get*",
        "ssm:Describe*",
        "ssm:List*",
        "route53:Get*",
        "route53:List*",
        "acm:Describe*",
        "acm:List*",
        "budgets:Describe*",
        "budgets:View*",
        "sts:GetCallerIdentity"
      ],
      "Resource": "*"
    },
    {
      "Sid": "StateBucketWrite",
      "Effect": "Allow",
      "Action": ["s3:PutObject", "s3:DeleteObject"],
      "Resource": [
        "${state_bucket_arn}/staging/*",
        "${state_bucket_arn}/frontend/staging/*"
      ]
    },
    {
      "Sid": "Ec2VpcStagingMutate",
      "Effect": "Allow",
      "Action": [
        "ec2:Create*",
        "ec2:Delete*",
        "ec2:Modify*",
        "ec2:Associate*",
        "ec2:Disassociate*",
        "ec2:Attach*",
        "ec2:Detach*",
        "ec2:Authorize*",
        "ec2:Revoke*",
        "ec2:RunInstances",
        "ec2:TerminateInstances",
        "ec2:Start*",
        "ec2:Stop*",
        "ec2:AllocateAddress",
        "ec2:ReleaseAddress",
        "ec2:CreateTags",
        "ec2:DeleteTags"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": { "aws:RequestTag/Environment": "staging" }
      }
    },
    {
      "Sid": "RdsStagingMutate",
      "Effect": "Allow",
      "Action": [
        "rds:Create*",
        "rds:Delete*",
        "rds:Modify*",
        "rds:Reboot*",
        "rds:AddTagsToResource",
        "rds:RemoveTagsFromResource"
      ],
      "Resource": [
        "arn:aws:rds:${aws_region}:${account_id}:db:dmair-staging*",
        "arn:aws:rds:${aws_region}:${account_id}:subgrp:dmair-staging*"
      ]
    },
    {
      "Sid": "SecretsStagingMutate",
      "Effect": "Allow",
      "Action": [
        "secretsmanager:Create*",
        "secretsmanager:Update*",
        "secretsmanager:Delete*",
        "secretsmanager:Put*",
        "secretsmanager:Restore*",
        "secretsmanager:TagResource",
        "secretsmanager:UntagResource"
      ],
      "Resource": "arn:aws:secretsmanager:${aws_region}:${account_id}:secret:dmair/staging/*"
    },
    {
      "Sid": "EcrDmairBackendMutate",
      "Effect": "Allow",
      "Action": [
        "ecr:Create*",
        "ecr:Delete*",
        "ecr:Put*",
        "ecr:Set*",
        "ecr:Tag*",
        "ecr:Untag*"
      ],
      "Resource": "arn:aws:ecr:${aws_region}:${account_id}:repository/dmair-backend"
    },
    {
      "Sid": "LogsStagingMutate",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:DeleteLogGroup",
        "logs:PutRetentionPolicy",
        "logs:TagLogGroup",
        "logs:UntagLogGroup"
      ],
      "Resource": "arn:aws:logs:${aws_region}:${account_id}:log-group:/dmair/staging*"
    },
    {
      "Sid": "IamStagingMutate",
      "Effect": "Allow",
      "Action": [
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:UpdateRole",
        "iam:UpdateAssumeRolePolicy",
        "iam:PutRolePolicy",
        "iam:DeleteRolePolicy",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",
        "iam:TagRole",
        "iam:UntagRole",
        "iam:CreateInstanceProfile",
        "iam:DeleteInstanceProfile",
        "iam:AddRoleToInstanceProfile",
        "iam:RemoveRoleFromInstanceProfile",
        "iam:CreatePolicy",
        "iam:DeletePolicy",
        "iam:CreatePolicyVersion",
        "iam:DeletePolicyVersion",
        "iam:SetDefaultPolicyVersion"
      ],
      "Resource": [
        "arn:aws:iam::${account_id}:role/dmair-staging-*",
        "arn:aws:iam::${account_id}:role/dmair-backend-staging-*",
        "arn:aws:iam::${account_id}:instance-profile/dmair-staging-*",
        "arn:aws:iam::${account_id}:policy/dmair-staging-*",
        "arn:aws:iam::${account_id}:policy/dmair-backend-staging-*"
      ]
    },
    {
      "Sid": "BudgetsStagingMutate",
      "Effect": "Allow",
      "Action": [
        "budgets:CreateBudget",
        "budgets:ModifyBudget",
        "budgets:DeleteBudget"
      ],
      "Resource": "arn:aws:budgets::${account_id}:budget/dmair-staging-*"
    }
  ]
}
