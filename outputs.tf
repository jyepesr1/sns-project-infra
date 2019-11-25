output "instance_ip_addr" {
  value = aws_ecr_repository.sns_ecr_repo.repository_url
}

output "alb_dns_name" {
  value = aws_alb.alb.dns_name
}

output "topic_arn" {
  value = aws_sns_topic.email_topic.arn
}