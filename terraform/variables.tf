variable "access_key" {}
variable "secret_key" {}
variable "private_key_path" {}

variable "region" {
  default = "us-east-2" # Oregon
}

variable "ami_centos" {
  default = "ami-9c0638f9"
}

variable "master_number" {
  default = "1"
}

variable "node_number" {
  default = "2"
}

variable "master_ec2_type" {
  default = "r4.xlarge"
}

variable "node_ec2_type" {
  default = "r4.xlarge"
}

variable "key_name" {
  default = "mykey"
}

variable "master_spot_price" {
  default = "0.10"
}

variable "node_spot_price" {
  default = "0.05"
}

variable "availability_zone" {
  default = "us-east-2b"
}
