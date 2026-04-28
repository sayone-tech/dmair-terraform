resource "aws_iam_user" "this" {
  name = var.user_name
  tags = var.tags
}

# Attach existing managed policies by ARN
resource "aws_iam_user_policy_attachment" "attach_managed" {
  for_each   = var.policy_arns_map
  user       = aws_iam_user.this.name
  policy_arn = each.value
}

resource "aws_iam_access_key" "this" {
  count = var.create_access_key ? 1 : 0
  user  = aws_iam_user.this.name
}
