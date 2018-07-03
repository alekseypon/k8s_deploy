terraform {
  backend "s3" {
    bucket = "apon-tf-deploy"
    key    = "terraform/kubernetes"
    region = "us-east-2"
  }
}
