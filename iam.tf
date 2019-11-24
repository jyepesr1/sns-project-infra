// Create ecs_role
resource "aws_iam_role" "ecs_role" {
  name = "ecs_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": ["ecs-tasks.amazonaws.com", "ec2.amazonaws.com"]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

// Allow ecs_role to publish to SNS topic
resource "aws_sns_topic_policy" "allow_publish_ssn" {
  arn = aws_sns_topic.email_topic.arn

  policy = data.aws_iam_policy_document.sns-topic-policy.json
}

data "aws_iam_policy_document" "sns-topic-policy" {
  statement {
    actions = ["SNS:Publish"]
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.ecs_role.arn]
    }
    resources = [aws_sns_topic.email_topic.arn]
  }
}

data "aws_iam_policy_document" "ssm_policy_doc" {
  statement {
    effect = "Allow"
    actions = [
      "ssm:GetParameters",
      "ssm:GetParameter"
    ]

    resources = [
      aws_ssm_parameter.arn_sns.arn
    ]
  }
}

resource "aws_iam_policy" "ssm_allow_policy" {
  name        = "ssmRead"
  description = "Read Only SSM Parameter SNS"

  policy = data.aws_iam_policy_document.ssm_policy_doc.json
}

resource "aws_iam_role_policy_attachment" "policy-attach" {
  role       = aws_iam_role.ecs_role.name
  policy_arn = aws_iam_policy.ssm_allow_policy.arn
}


data "aws_iam_policy" "AmazonECSTaskExecutionRolePolicy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}


resource "aws_iam_role_policy_attachment" "policy-attach-2" {
  role       = aws_iam_role.ecs_role.name
  policy_arn = data.aws_iam_policy.AmazonECSTaskExecutionRolePolicy.arn
}


resource "aws_iam_role" "ecs_autoscale_role" {
  name = "ecs_autoscale_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "application-autoscaling.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

data "aws_iam_policy_document" "autoscale_policy_doc" {
  statement {
    effect = "Allow"
    actions = [
      "ecs:DescribeServices",
      "ecs:UpdateService"
    ]
    resources = [ "*" ]
  }

  statement {
    effect = "Allow"
    actions = [ "cloudwatch:DescribeAlarms" ]
    resources = [ "*" ]
  }

}

resource "aws_iam_policy" "ecs_autoscale_policy" {
  name        = "autoscale_cloudwatch"
  description = "Read CloudWatch Metrics for autoscaling"

  policy = data.aws_iam_policy_document.autoscale_policy_doc.json
}

resource "aws_iam_role_policy_attachment" "policy-attach-autoscale" {
  role       = aws_iam_role.ecs_autoscale_role.name
  policy_arn = aws_iam_policy.ecs_autoscale_policy.arn
}
