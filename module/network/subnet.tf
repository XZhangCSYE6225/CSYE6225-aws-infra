resource "aws_subnet" "public_subnet" {
  count             = var.length
  vpc_id            = aws_vpc.xiao.id
  availability_zone = "${var.region}${element(var.aval_zone, count.index)}"
  cidr_block        = cidrsubnet(var.public_route_cidr, 4, count.index)

  tags = {
    Name = "public-subnet-${count.index + 0}"
  }
}

resource "aws_subnet" "private_subnet" {
  count             = var.length
  vpc_id            = aws_vpc.xiao.id
  availability_zone = "${var.region}${element(var.aval_zone, count.index)}"
  cidr_block        = cidrsubnet(var.private_route_cidr, 4, count.index)

  tags = {
    Name = "private-subnet-${count.index + 0}"
  }
}

resource "aws_route_table_association" "route_table_association" {
  count          = var.length
  subnet_id      = element(aws_subnet.public_subnet.*.id, count.index)
  route_table_id = aws_route_table.public.id
}