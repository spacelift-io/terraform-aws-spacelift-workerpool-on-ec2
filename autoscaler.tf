module "autoscaler" {
  source = "github.com/spacelift-io/ec2-workerpool-autoscaler//iac"

  for_each = var.enable_autoscaling ? toset(["ENABLED"]) : toset([])

  autoscaling_group_arn      = var.autoscaling_group_arn
  autoscaler_version         = var.autoscaler_version
  spacelift_api_key_id       = var.spacelift_api_key_id
  spacelift_api_key_secret   = var.spacelift_api_key_secret
  spacelift_api_key_endpoint = var.spacelift_api_key_endpoint
  worker_pool_id             = var.worker_pool_id
  autoscaler_architecture    = var.autoscaler_architecture
  autoscaling_timeout        = var.autoscaling_timeout
  autoscaling_max_create     = var.autoscaling_max_create
  autoscaling_max_terminate  = var.autoscaling_max_terminate
  schedule_expression        = var.schedule_expression
  base_name                  = var.base_name
  region                     = var.region
  autoscaler_s3_package      = var.autoscaler_s3_package
  subnet_ids                 = var.vpc_subnets
  security_group_ids         = var.security_groups

  depends_on = [module.asg]
}

moved {
  from = aws_ssm_parameter.spacelift_api_key_secret[0]
  to   = module.autoscaler["ENABLED"].aws_ssm_parameter.spacelift_api_key_secret
}

moved {
  from = null_resource.download[0]
  to   = module.autoscaler["ENABLED"].null_resource.download
}

moved {
  from = aws_lambda_function.autoscaler[0]
  to   = module.autoscaler["ENABLED"].aws_lambda_function.autoscaler
}

moved {
  from = aws_cloudwatch_event_rule.scheduling[0]
  to   = module.autoscaler["ENABLED"].aws_cloudwatch_event_rule.scheduling
}

moved {
  from = aws_cloudwatch_event_target.scheduling[0]
  to   = module.autoscaler["ENABLED"].aws_cloudwatch_event_target.scheduling
}

moved {
  from = aws_lambda_permission.allow_cloudwatch_to_call_lambda[0]
  to   = module.autoscaler["ENABLED"].aws_lambda_permission.allow_cloudwatch_to_call_lambda
}

moved {
  from = aws_cloudwatch_log_group.log_group[0]
  to   = module.autoscaler["ENABLED"].aws_cloudwatch_log_group.log_group
}

moved {
  from = aws_iam_role.autoscaler[0]
  to   = module.autoscaler["ENABLED"].aws_iam_role.autoscaler
}
