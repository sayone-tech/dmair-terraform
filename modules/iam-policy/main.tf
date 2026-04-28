locals {
  templates = { for t in var.policy_templates : t => templatefile("${path.module}/../../policies/${t}.tpl", var.template_vars[t]) }
}

resource "aws_iam_policy" "this" {
  for_each = local.templates
  name     = lower("${var.name_prefix}-${each.key}")
  policy   = each.value
  tags     = var.tags
}
