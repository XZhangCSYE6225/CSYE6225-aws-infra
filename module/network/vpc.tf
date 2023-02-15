resource "aws_vpc" "xiao" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = "xiao-vpc"
  }
}