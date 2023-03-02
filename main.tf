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
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "database_sg" {
  vpc_id = module.mynetwork.vpc.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
    security_groups = [aws_security_group.webapp_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_subnet_group" "private" {
  name       = "private-subnets-group"
  subnet_ids = module.mynetwork.private_subnets.*.id
}

resource "aws_db_parameter_group" "mysql" {
  name        = "mysql-parameters"
  family      = "mysql8.0"
  description = "mysql8.0 parameter group"
}

resource "aws_db_instance" "csye6225" {
  db_name                = "csye6225"
  identifier             = "csye6225"
  allocated_storage      = 8
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  username               = "csye6225"
  password               = "Zx991115!"
  publicly_accessible    = false
  vpc_security_group_ids = [aws_security_group.database_sg.id]
  parameter_group_name   = aws_db_parameter_group.mysql.name
  db_subnet_group_name   = aws_db_subnet_group.private.name
  skip_final_snapshot    = true
  multi_az               = false

  tags = {
    Name = "csye6225"
  }
}

resource "aws_s3_bucket" "s3_bucket" {
  bucket_prefix = "my-webapp-bucket-"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "block" {
  bucket = aws_s3_bucket.s3_bucket.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "s3_bucket_encryption" {
  bucket = aws_s3_bucket.s3_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "s3_bucket_lifecycle" {
  bucket = aws_s3_bucket.s3_bucket.id

  rule {
    id     = "s3_bucket"
    status = "Enabled"

    transition {
      days          = 60
      storage_class = "STANDARD_IA"
    }
  }
}

data "aws_ami" "webapp" {
  name_regex  = "webapp-ami-*"
  most_recent = true
}

locals {
  ami_id = var.ami_id == "" ? data.aws_ami.webapp.id : var.ami_id
}

resource "aws_iam_policy" "WebAppS3" {
  name = "WebAppS3"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ],
        "Effect" : "Allow",
        "Resource" : [
          "arn:aws:s3:::${aws_s3_bucket.s3_bucket.bucket}",
          "arn:aws:s3:::${aws_s3_bucket.s3_bucket.bucket}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role" "EC2-CSYE6225" {
  name = "EC2-CSYE6225"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "EC2-CSYE6225"
  }
}

resource "aws_iam_role_policy_attachment" "attachment" {
  role       = aws_iam_role.EC2-CSYE6225.name
  policy_arn = aws_iam_policy.WebAppS3.arn
}

resource "aws_iam_instance_profile" "profile" {
  name = "EC2-CSYE6225"
  role = aws_iam_role.EC2-CSYE6225.name
}

resource "aws_instance" "webapp" {
  ami                         = local.ami_id
  instance_type               = var.instance_type
  vpc_security_group_ids      = [aws_security_group.webapp_sg.id]
  key_name                    = var.key_name
  subnet_id                   = module.mynetwork.public_subnets.*.id[0]
  iam_instance_profile        = aws_iam_instance_profile.profile.name
  disable_api_termination     = false
  associate_public_ip_address = true

  user_data = <<EOF
    #!/bin/bash
    echo "DATABASE_HOST=${replace(aws_db_instance.csye6225.endpoint, "/:.*/", "")}" >> /home/ec2-user/.env
    echo "DATABASE_NAME=${aws_db_instance.csye6225.db_name}" >> /home/ec2-user/.env
    echo "DATABASE_USERNAME=${aws_db_instance.csye6225.username}" >> /home/ec2-user/.env
    echo "DATABASE_PASSWORD=${aws_db_instance.csye6225.password}" >> /home/ec2-user/.env
    echo "DIALECT=${aws_db_instance.csye6225.engine}" >> /home/ec2-user/.env
    echo "AWS_BUCKET_NAME=${aws_s3_bucket.s3_bucket.bucket}" >> /home/ec2-user/.env
    echo "AWS_BUCKET_REGION=${var.vpc_region}" >> /home/ec2-user/.env
    mv /home/ec2-user/.env /home/ec2-user/webapp/.env
  EOF

  root_block_device {
    delete_on_termination = true
    volume_size           = var.volume_size
    volume_type           = var.volume_type
  }

  tags = {
    Name = "webapp-ec2"
  }
}