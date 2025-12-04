data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_organizations_organization" "current" {}

data "template_file" "lambda_assume_role_policy" {
  template = file("${path.module}/policies/lambda-assume-role-policy.json")
}

data "template_file" "lambda_policy" {
  template = file("${path.module}/policies/lambda-policy.json")
  
  vars = {
    aws_region    = data.aws_region.current.name
    account_id    = data.aws_caller_identity.current.account_id
    function_name = local.lambda_function_name
    bucket_arn    = aws_s3_bucket.reports.arn
  }
}

data "archive_file" "lambda_layer" {
  type        = "zip"
  source_dir  = "${path.module}/layer"
  output_path = "${path.module}/lambda_layer.zip"

  depends_on = [null_resource.lambda_layer]
}

data "archive_file" "lambda_code" {
  type        = "zip"
  source_file = "${path.module}/lambda_function.py"
  output_path = "${path.module}/lambda_function.zip"
}
