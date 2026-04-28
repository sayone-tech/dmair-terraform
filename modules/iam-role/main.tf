resource "aws_iam_role" "this" {
  name               = var.role_name
  assume_role_policy = var.assume_role_policy
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "attach_managed" {
  for_each   = var.policy_arns_map
  role       = aws_iam_role.this.name
  policy_arn = each.value
}
