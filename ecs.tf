
/*====
ECR repository to store our Docker images
======*/
resource "aws_ecr_repository" "sns_ecr_repo" {
  name = "sns-project"

  image_scanning_configuration {
    scan_on_push = true
  }
}

/*====
ECS cluster
======*/
resource "aws_ecs_cluster" "cluster" {
  name = "sns-ecs-cluster"
}

/*====
ECS task definitions
======*/
data "template_file" "task_definition" {
  template = file("./task_definition.json")

  vars = {
    image   = aws_ecr_repository.sns_ecr_repo.repository_url
    arn_ssm_parameter = aws_ssm_parameter.arn_sns.arn
    app_port = var.app_port
  }
}

resource "aws_ecs_task_definition" "sns-project-task-def" {
  family                   = "sns-project-task-def"
  container_definitions    = data.template_file.task_definition.rendered
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_role.arn
  task_role_arn            = aws_iam_role.ecs_role.arn
}

/*====
ECS service
======*/
resource "aws_security_group" "ecs_service-sg" {
  vpc_id      = aws_vpc.main_vpc.id
  name        = "ecs-service-sg"
  description = "Allow egress from container"

  ingress {
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    security_groups = [aws_security_group.alb_inbound_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "ecs-service-sg-egress"
  }
}

data "aws_ecs_task_definition" "sns-project-task-def" {
  task_definition = aws_ecs_task_definition.sns-project-task-def.family
}


resource "aws_ecs_service" "sns_project_service" {
  name            = "sns_project_service"
  task_definition = "${aws_ecs_task_definition.sns-project-task-def.family}:${max("${aws_ecs_task_definition.sns-project-task-def.revision}", "${data.aws_ecs_task_definition.sns-project-task-def.revision}")}"
  desired_count   = 2
  launch_type     = "FARGATE"
  cluster         = aws_ecs_cluster.cluster.id

  network_configuration {
    security_groups = [aws_security_group.ecs_service-sg.id]
    subnets         = [aws_subnet.private_1.id]
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.alb_target_group.arn
    container_name   = "sns-project"
    container_port   = var.app_port
  }

  depends_on = [aws_alb_target_group.alb_target_group]
}

/*==========
Auto Scaling
===========*/
resource "aws_appautoscaling_target" "target" {
  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.cluster.name}/${aws_ecs_service.sns_project_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = 1
  max_capacity       = 2
}

resource "aws_appautoscaling_policy" "up" {
  name                    = "scale_up"
  service_namespace       = "ecs"
  resource_id             = "service/${aws_ecs_cluster.cluster.name}/${aws_ecs_service.sns_project_service.name}"
  scalable_dimension      = "ecs:service:DesiredCount"


  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Maximum"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment = 1
    }
  }

  depends_on = [aws_appautoscaling_target.target]
}

resource "aws_appautoscaling_policy" "down" {
  name                    = "scale_down"
  service_namespace       = "ecs"
  resource_id             = "service/${aws_ecs_cluster.cluster.name}/${aws_ecs_service.sns_project_service.name}"
  scalable_dimension      = "ecs:service:DesiredCount"

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Maximum"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment = -1
    }
  }

  depends_on = [aws_appautoscaling_target.target]
}

/* metric used for auto scale */
resource "aws_cloudwatch_metric_alarm" "service_cpu_high" {
  alarm_name          = "cpu_utilization_high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Maximum"
  threshold           = "85"

  dimensions = {
    ClusterName = aws_ecs_cluster.cluster.name
    ServiceName = aws_ecs_service.sns_project_service.name
  }

  alarm_actions = [aws_appautoscaling_policy.up.arn]
  ok_actions    = [aws_appautoscaling_policy.down.arn]
}