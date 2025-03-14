moved {
  to   = aws_ssm_parameter.spacelift_api_key_secret[0]
  from = module.autoscaler["ENABLED"].aws_ssm_parameter.spacelift_api_key_secret
}

moved {
  to   = null_resource.download[0]
  from = module.autoscaler["ENABLED"].null_resource.download
}

moved {
  to   = aws_lambda_function.autoscaler[0]
  from = module.autoscaler["ENABLED"].aws_lambda_function.autoscaler
}

moved {
  to   = aws_cloudwatch_event_rule.scheduling[0]
  from = module.autoscaler["ENABLED"].aws_cloudwatch_event_rule.scheduling
}

moved {
  to   = aws_cloudwatch_event_target.scheduling[0]
  from = module.autoscaler["ENABLED"].aws_cloudwatch_event_target.scheduling
}

moved {
  to   = aws_lambda_permission.allow_cloudwatch_to_call_lambda[0]
  from = module.autoscaler["ENABLED"].aws_lambda_permission.allow_cloudwatch_to_call_lambda
}

moved {
  to   = aws_cloudwatch_log_group.log_group[0]
  from = module.autoscaler["ENABLED"].aws_cloudwatch_log_group.log_group
}

moved {
  to   = aws_iam_role.autoscaler[0]
  from = module.autoscaler["ENABLED"].aws_iam_role.autoscaler
}