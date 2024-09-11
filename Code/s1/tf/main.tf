terraform {
    required_version = "~> 1.0"
}

provider "aws" {
  region  = var.region
  profile = var.aws_profile
}

data "aws_caller_identity" "current" {}

output "account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "caller_arn" {
  value = data.aws_caller_identity.current.arn
}

output "caller_user" {
  value = data.aws_caller_identity.current.user_id
}

resource "aws_budgets_budget" "ec2" {
  name              = "budget-ec2-monthly"
  budget_type       = "COST"
  limit_amount      = "12"
  limit_unit        = "USD"
  time_period_end   = "2087-06-15_00:00"
  time_period_start = "2022-05-25_00:00"
  time_unit         = "MONTHLY"

  cost_filter {
    name = "Service"
    values = [
      "Amazon Elastic Compute Cloud - Compute",
    ]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = ["fmorenod@gmail.com"]
  }
}