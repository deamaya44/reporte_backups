# ==============================================================================
# S3 BUCKET PARA REPORTES
# ==============================================================================

resource "aws_s3_bucket" "reports" {
  bucket = local.bucket_name

  tags = merge(
    local.common_tags,
    {
      Description = "Almacenamiento de reportes de backup"
    }
  )
}

resource "aws_s3_bucket_versioning" "reports" {
  bucket = aws_s3_bucket.reports.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "reports" {
  bucket = aws_s3_bucket.reports.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "reports" {
  bucket = aws_s3_bucket.reports.id

  rule {
    id     = "delete-old-reports"
    status = "Enabled"

    expiration {
      days = local.s3_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

resource "aws_s3_bucket_public_access_block" "reports" {
  bucket = aws_s3_bucket.reports.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ==============================================================================
# IAM ROLE PARA LAMBDA
# ==============================================================================

resource "aws_iam_role" "lambda" {
  name = "${local.lambda_function_name}-role"

  assume_role_policy = data.template_file.lambda_assume_role_policy.rendered

  tags = local.common_tags
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "${local.lambda_function_name}-policy"
  role = aws_iam_role.lambda.id

  policy = data.template_file.lambda_policy.rendered
}

# ==============================================================================
# LAMBDA LAYER PARA DEPENDENCIAS
# ==============================================================================

resource "null_resource" "lambda_layer" {
  triggers = {
    requirements = filemd5("${path.module}/requirements.txt")
  }

  provisioner "local-exec" {
    command = <<EOF
      mkdir -p ${path.module}/layer/python
      pip install -r ${path.module}/requirements.txt -t ${path.module}/layer/python/ --platform manylinux2014_x86_64 --only-binary=:all:
    EOF
  }
}

resource "aws_lambda_layer_version" "dependencies" {
  filename            = data.archive_file.lambda_layer.output_path
  layer_name          = "${local.lambda_function_name}-dependencies"
  compatible_runtimes = ["python3.11", "python3.12"]
  source_code_hash    = data.archive_file.lambda_layer.output_base64sha256

  depends_on = [data.archive_file.lambda_layer]
}

# ==============================================================================
# LAMBDA FUNCTION
# ==============================================================================

resource "aws_lambda_function" "backup_reporter" {
  filename         = data.archive_file.lambda_code.output_path
  function_name    = local.lambda_function_name
  role             = aws_iam_role.lambda.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.lambda_code.output_base64sha256
  runtime          = "python3.11"
  timeout          = local.lambda_timeout
  memory_size      = local.lambda_memory_size

  layers = [aws_lambda_layer_version.dependencies.arn]

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.reports.id
      FROM_EMAIL  = local.from_email
      TO_EMAILS   = join(",", local.to_emails)
      CC_EMAILS   = join(",", local.cc_emails)
    }
  }

  tags = local.common_tags

  depends_on = [
    aws_iam_role_policy.lambda_policy,
    aws_cloudwatch_log_group.lambda
  ]
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${local.lambda_function_name}"
  retention_in_days = 30

  tags = local.common_tags
}

# ==============================================================================
# EVENTBRIDGE RULE PARA EJECUCIÓN PROGRAMADA
# ==============================================================================

resource "aws_cloudwatch_event_rule" "schedule" {
  name                = "${local.lambda_function_name}-schedule"
  description         = "Ejecuta el reporte de backups diariamente"
  schedule_expression = local.schedule_expression

  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule      = aws_cloudwatch_event_rule.schedule.name
  target_id = "lambda"
  arn       = aws_lambda_function.backup_reporter.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.backup_reporter.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.schedule.arn
}

# ==============================================================================
# SES EMAIL VERIFICATION
# ==============================================================================

resource "aws_ses_email_identity" "from_email" {
  email = local.from_email
}

resource "aws_ses_email_identity" "to_emails" {
  for_each = toset(local.to_emails)
  email    = each.value
}

resource "aws_ses_email_identity" "cc_emails" {
  for_each = toset(local.cc_emails)
  email    = each.value
}
