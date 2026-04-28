{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "UpdateSecurityGroupIngress",
      "Effect": "Allow",
      "Action": [
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:RevokeSecurityGroupIngress"
      ],
      "Resource": ${jsonencode(security_group_arn)}
    },
    {
      "Sid": "DescribeSecurityGroups",
      "Effect": "Allow",
      "Action": "ec2:DescribeSecurityGroups",
      "Resource": "*"
    }
  ]
}
