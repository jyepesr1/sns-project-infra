resource "aws_sns_topic" "email_topic" {
  name = "email_topic"
  delivery_policy = <<JSON
{
  "http": {
    "defaultHealthyRetryPolicy": {
      "minDelayTarget"    : 20,
      "maxDelayTarget"    : 600,
      "numRetries"        : 5,
      "backoffFunction"   : "exponential"
    },
    "disableSubscriptionOverrides": false
  }
}
JSON
}

resource "aws_ssm_parameter" "arn_sns" {
  name  = "arn_sns"
  type  = "String"
  value = aws_sns_topic.email_topic.arn
}
