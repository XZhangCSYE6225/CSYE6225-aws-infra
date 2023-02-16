variable "vpc_region" {
  type    = string
  default = "us-east-1"
}

variable "name" {
  type    = string
  default = "network1"
}

variable "profile" {
  type    = string
  default = "dev"
}

variable "cidr_block" {
  type    = string
  default = "10.0.0.0/16"
}