{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:ListBucket"],
      "Resource": ${jsonencode(s3_bucket_arns)}
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": ${jsonencode([for arn in s3_bucket_arns : format("%s/*", arn)])}
    }
  ]
}
