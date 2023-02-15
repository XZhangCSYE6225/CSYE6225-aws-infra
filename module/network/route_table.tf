resource "aws_route_table" "public" {
  vpc_id = aws_vpc.xiao.id

  route {
    gateway_id = aws_internet_gateway.gateway.id
    cidr_block = "10.0.0.0/8"
  }

  tags = {
    Name = "${var.vpc_name}-public-route-table"
  }
}

resource "aws_default_route_table" "private" {
  default_route_table_id = aws_vpc.xiao.default_route_table_id

  route = []

  tags = {
    Name = "${var.vpc_name}-private-route-table"
  }
}