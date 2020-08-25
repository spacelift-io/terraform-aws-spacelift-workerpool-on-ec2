module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 5.0"

  name               = local.namespace
  load_balancer_type = "application"
  internal           = true

  vpc_id          = var.vpc_id
  security_groups = var.security_groups
  subnets         = var.vpc_subnets

  target_groups = [
    {
      backend_protocol     = "HTTP"
      backend_port         = 2112
      target_type          = "instance"
      deregistration_delay = 1

      health_check = {
        enabled             = true
        interval            = 30
        path                = "/health"
        port                = "traffic-port"
        healthy_threshold   = 2
        unhealthy_threshold = 2
        timeout             = 5
        protocol            = "HTTP"
        matcher             = "200"
      }
    }
  ]

  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0
    }
  ]
}
