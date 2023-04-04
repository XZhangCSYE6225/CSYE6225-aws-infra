module "mynetwork" {
  source   = "./module/network"
  vpc_cidr = var.cidr_block
  region   = var.vpc_region
  vpc_name = var.name
  profile  = var.profile
}

resource "aws_security_group" "webapp_sg" {
  name        = "webapp_sg"
  description = "allow on port 80 8080"
  vpc_id      = module.mynetwork.vpc.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.webapp_lb_sg.id]
  }

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.webapp_lb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "webapp_lb_sg" {
  name   = "lb_sg"
  vpc_id = module.mynetwork.vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
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
  name   = "database_sg"

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
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
  password               = var.db_password
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
      days          = 30
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

resource "aws_iam_role_policy_attachment" "S3Attachment" {
  role       = aws_iam_role.EC2-CSYE6225.name
  policy_arn = aws_iam_policy.WebAppS3.arn
}

resource "aws_iam_role_policy_attachment" "CWAttachment" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.EC2-CSYE6225.name
}

resource "aws_iam_instance_profile" "profile" {
  name = "EC2-CSYE6225"
  role = aws_iam_role.EC2-CSYE6225.name
}

data "template_file" "userdata" {
  template = <<EOF
    #!/bin/bash
    echo "DATABASE_HOST=${replace(aws_db_instance.csye6225.endpoint, "/:.*/", "")}" >> /home/ec2-user/.env
    echo "DATABASE_NAME=${aws_db_instance.csye6225.db_name}" >> /home/ec2-user/.env
    echo "DATABASE_USERNAME=${aws_db_instance.csye6225.username}" >> /home/ec2-user/.env
    echo "DATABASE_PASSWORD=${aws_db_instance.csye6225.password}" >> /home/ec2-user/.env
    echo "DIALECT=${aws_db_instance.csye6225.engine}" >> /home/ec2-user/.env
    echo "AWS_BUCKET_NAME=${aws_s3_bucket.s3_bucket.bucket}" >> /home/ec2-user/.env
    echo "AWS_BUCKET_REGION=${var.vpc_region}" >> /home/ec2-user/.env
    mv /home/ec2-user/.env /home/ec2-user/webapp/.env
    sudo ln -s /home/ec2-user/webapp/logs/app.log /var/log/webapp/app.log
    sleep 10
    sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -c file:/opt/config.json \
    -s
    EOF
}

resource "aws_launch_template" "webapp_lt" {
  name                    = "asg_launch_config"
  image_id                = local.ami_id
  instance_type           = var.instance_type
  key_name                = var.key_name
  user_data               = base64encode(data.template_file.userdata.rendered)
  disable_api_termination = false
  network_interfaces {
    associate_public_ip_address = true
    delete_on_termination       = true
    security_groups             = [aws_security_group.webapp_sg.id]
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.profile.name
  }
}

resource "aws_autoscaling_group" "webapp_asg" {
  name             = "csye6225-asg-spring2023"
  desired_capacity = 1
  max_size         = 3
  min_size         = 1
  default_cooldown = 60
  launch_template {
    id      = aws_launch_template.webapp_lt.id
    version = "$Latest"
  }
  vpc_zone_identifier = module.mynetwork.public_subnets.*.id
  target_group_arns   = [aws_lb_target_group.alb_tg.arn]
  tag {
    key                 = "Name"
    value               = "webapp-asg"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "scale_up" {
  name                   = "scale_up_policy"
  cooldown               = 120
  autoscaling_group_name = aws_autoscaling_group.webapp_asg.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  policy_type            = "SimpleScaling"
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "scale_down_policy"
  cooldown               = 120
  autoscaling_group_name = aws_autoscaling_group.webapp_asg.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  policy_type            = "SimpleScaling"
}

resource "aws_cloudwatch_metric_alarm" "scale_down_alarm" {
  alarm_name          = "scale_down_alarm"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "3"
  alarm_actions       = [aws_autoscaling_policy.scale_down.arn]
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.webapp_asg.name
  }
}

resource "aws_cloudwatch_metric_alarm" "scale_up_alarm" {
  alarm_name          = "scale_up_alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "5"
  alarm_actions       = [aws_autoscaling_policy.scale_up.arn]
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.webapp_asg.name
  }
}

resource "aws_lb" "webapp_lb" {
  name               = "csye6225-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.webapp_lb_sg.id]
  subnets            = module.mynetwork.public_subnets.*.id

  tags = {
    Application = "WebApp"
  }
}

resource "aws_lb_target_group" "alb_tg" {
  name     = "webapp-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = module.mynetwork.vpc.id

  health_check {
    path     = "/healthz"
    port     = "8080"
    protocol = "HTTP"
  }
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.webapp_lb.arn
  protocol          = "HTTP"
  port              = 80

  default_action {
    target_group_arn = aws_lb_target_group.alb_tg.arn
    type             = "forward"
  }
}

resource "aws_route53_record" "webapp_record" {
  zone_id = var.zone_id
  name    = "${var.subdoumain_prefix}.xiaozhang99.me"
  type    = "A"

  alias {
    name                   = aws_lb.webapp_lb.dns_name
    zone_id                = aws_lb.webapp_lb.zone_id
    evaluate_target_health = true
  }
}