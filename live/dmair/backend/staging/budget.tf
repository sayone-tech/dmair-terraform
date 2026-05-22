# Monthly cost budget + SNS-less email alert. AWS Budgets natively supports
# direct email recipients on the notification; an SNS topic is unnecessary
# for staging.

resource "aws_budgets_budget" "staging" {
  name              = "dmair-staging-monthly"
  budget_type       = "COST"
  time_unit         = "MONTHLY"
  time_period_start = "2026-05-01_00:00"

  limit_amount = tostring(var.budget_monthly_cap_usd)
  limit_unit   = "USD"

  cost_filter {
    name = "TagKeyValue"
    values = [
      "user:Project$dmair",
      "user:Environment$staging",
    ]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_alert_email]
  }
}
