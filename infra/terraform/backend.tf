# Remote state in GCS. Partial config: the bucket is passed at init time by
# infra/scripts/bootstrap.sh:
#   terraform init -reconfigure -backend-config="bucket=<project_id>-tfstate"
# CI and local validation use `terraform init -backend=false`.
terraform {
  backend "gcs" {
    prefix = "terraform/aimesis"
  }
}
