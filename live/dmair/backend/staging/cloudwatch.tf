resource "aws_cloudwatch_log_group" "staging" {
  name              = "/dmair/staging"
  retention_in_days = 5

  tags = {
    Name = "dmair-staging-logs"
  }
}
