terraform {
  backend "s3" {
    bucket         = "terraform-state-backup-reporter-650251728104"
    key            = "backup-reporter/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    use_lockfile = true
  }
}
