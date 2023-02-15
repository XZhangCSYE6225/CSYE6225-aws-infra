resource "aws_internet_gateway" "gateway" {
  vpc_id = aws_vpc.xiao.id

  tags = {
    Name = "${var.vpc_name}-igw"
  }
}