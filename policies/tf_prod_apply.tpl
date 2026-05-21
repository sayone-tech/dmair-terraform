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
      "Sid": "StateBucketWriteAll",
      "Effect": "Allow",
      "Action": ["s3:PutObject", "s3:DeleteObject"],
      "Resource": "${state_bucket_arn}/*"
    },
    {
      "Sid": "BootstrapBucketManage",
      "Effect": "Allow",
      "Action": [
        "s3:PutBucket*",
        "s3:DeleteBucket*",
        "s3:PutEncryptionConfiguration",
        "s3:PutLifecycleConfiguration",
        "s3:PutBucketPolicy",
        "s3:PutBucketTagging",
        "s3:PutBucketVersioning",
        "s3:PutPublicAccessBlock"
      ],
      "Resource": "${state_bucket_arn}"
    },
    {
      "Sid": "Ec2VpcProdMutate",
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
      "Resource": "*"
    },
    {
      "Sid": "CloudfrontProdMutate",
      "Effect": "Allow",
      "Action": [
        "cloudfront:Create*",
        "cloudfront:Update*",
        "cloudfront:Delete*",
        "cloudfront:Tag*",
        "cloudfront:Untag*",
        "cloudfront:CreateInvalidation"
      ],
      "Resource": "*"
    },
    {
      "Sid": "S3ProdMutate",
      "Effect": "Allow",
      "Action": [
        "s3:CreateBucket",
        "s3:DeleteBucket",
        "s3:PutBucket*",
        "s3:PutEncryptionConfiguration",
        "s3:PutLifecycleConfiguration",
        "s3:PutBucketPolicy",
        "s3:DeleteBucketPolicy",
        "s3:PutBucketTagging",
        "s3:PutBucketVersioning",
        "s3:PutPublicAccessBlock",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": "*"
    },
    {
      "Sid": "SecretsProdMutate",
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
      "Resource": "*"
    },
    {
      "Sid": "IamProdMutate",
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
        "iam:SetDefaultPolicyVersion",
        "iam:CreateUser",
        "iam:DeleteUser",
        "iam:UpdateUser",
        "iam:CreateAccessKey",
        "iam:DeleteAccessKey",
        "iam:AttachUserPolicy",
        "iam:DetachUserPolicy",
        "iam:PutUserPolicy",
        "iam:DeleteUserPolicy",
        "iam:TagUser",
        "iam:UntagUser"
      ],
      "Resource": [
        "arn:aws:iam::${account_id}:role/strapi-*",
        "arn:aws:iam::${account_id}:role/frontend-*",
        "arn:aws:iam::${account_id}:role/dmair-prod-*",
        "arn:aws:iam::${account_id}:role/cms-*",
        "arn:aws:iam::${account_id}:instance-profile/strapi-*",
        "arn:aws:iam::${account_id}:instance-profile/dmair-prod-*",
        "arn:aws:iam::${account_id}:user/github-actions-*",
        "arn:aws:iam::${account_id}:user/strapi-*",
        "arn:aws:iam::${account_id}:user/frontend-*",
        "arn:aws:iam::${account_id}:policy/strapi-*",
        "arn:aws:iam::${account_id}:policy/frontend-*",
        "arn:aws:iam::${account_id}:policy/dmair-prod-*",
        "arn:aws:iam::${account_id}:policy/cms-*"
      ]
    },
    {
      "Sid": "EcrProdMutate",
      "Effect": "Allow",
      "Action": [
        "ecr:Create*",
        "ecr:Delete*",
        "ecr:Put*",
        "ecr:Set*",
        "ecr:Tag*",
        "ecr:Untag*"
      ],
      "Resource": "arn:aws:ecr:${aws_region}:${account_id}:repository/*"
    },
    {
      "Sid": "LogsProdMutate",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:DeleteLogGroup",
        "logs:PutRetentionPolicy",
        "logs:TagLogGroup",
        "logs:UntagLogGroup"
      ],
      "Resource": "*"
    }
  ]
}
