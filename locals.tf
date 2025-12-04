locals {
  # Configuración general
  aws_region   = "us-east-1"
  project_name = "backup-reporter"
  environment  = "prod"
  
  # Configuración de emails
  from_email = "david.amaya@axity.com"
  to_emails  = ["Luis.PerezR@axity.com"]
  cc_emails  = []
  
  # Configuración de Lambda
  lambda_timeout      = 300
  lambda_memory_size  = 512
  schedule_expression = "cron(15 10 * * ? *)"  # 7:15 AM Chile
  
  # Retención S3
  s3_retention_days = 90
  
  # Tags
  default_tags = {
    Project     = "BackupReporter"
    ManagedBy   = "Terraform"
    Environment = "Production"
    Team        = "Infrastructure"
  }
  
  # Nombres de recursos
  lambda_function_name = "${local.project_name}-${local.environment}"
  bucket_name          = "${local.project_name}-reports-${local.environment}-${data.aws_caller_identity.current.account_id}"
  
  common_tags = merge(
    local.default_tags,
    {
      Name = local.lambda_function_name
    }
  )
}
