{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "cloudfront:GetDistribution",
        "cloudfront:GetInvalidation",
        "cloudfront:CreateInvalidation"
      ],
      "Resource": ${jsonencode(cloudfront_distribution_arns)}
    },
    {
      "Effect": "Allow",
      "Action": ["cloudfront:ListDistributions"],
      "Resource": "*"
    }
  ]
}
