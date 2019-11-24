output "instance_ip_addr" {
  value = aws_ecr_repository.sns_ecr_repo.repository_url
}