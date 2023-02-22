module "mynetwork" {
  source   = "./module/network"
  vpc_cidr = var.cidr_block
  region   = var.vpc_region
  vpc_name = var.name
  profile  = var.profile
}

resource "aws_security_group" "webapp_sg" {
  name        = "app_sg"
  description = "allow on port 22 80 443 8080"
  vpc_id      = module.mynetwork.vpc.id

  ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    from_port        = 3306
    to_port          = 3306
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_key_pair" "ec2" {
  key_name   = var.key_name
  public_key = var.public_key
}

data "aws_ami" "webapp" {
  name_regex  = "webapp-*"
  most_recent = true
}

resource "aws_instance" "webapp" {
  ami                         = data.aws_ami.webapp.id
  instance_type               = "t2.micro"
  vpc_security_group_ids      = [aws_security_group.webapp_sg.id]
  key_name                    = var.key_name
  subnet_id                   = module.mynetwork.public_subnets.*.id[0]
  disable_api_termination     = false
  associate_public_ip_address = true

  root_block_device {
    delete_on_termination = true
    volume_size           = 50
    volume_type           = "gp2"
  }

  tags = {
    Name = "webapp_instance"
  }
}