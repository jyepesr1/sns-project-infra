resource "aws_alb_target_group" "alb_target_group" {
  name     = "tg-sns-project"
  port     = var.app_port
  protocol = "HTTP"
  vpc_id   = aws_vpc.main_vpc.id
  target_type = "ip"

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_alb.alb]
}

/* security group for ALB */
resource "aws_security_group" "alb_inbound_sg" {
  name        = "alb_inbound_sg"
  description = "Allow HTTP from Anywhere into ALB"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb_inbound_sg"
  }
}

resource "aws_alb" "alb" {
  name            = "alb-sns-project"
  subnets         = [aws_subnet.public_1.id, aws_subnet.public_2.id]
  security_groups = [aws_security_group.alb_inbound_sg.id]

  tags = {
    Name        = "alb-sns-project"
  }
}

resource "aws_alb_listener" "sns-project-listener" {
  load_balancer_arn = aws_alb.alb.arn
  port              = var.app_port
  protocol          = "HTTP"
  depends_on        = [aws_alb_target_group.alb_target_group]

  default_action {
    target_group_arn = aws_alb_target_group.alb_target_group.arn
    type             = "forward"
  }
}
