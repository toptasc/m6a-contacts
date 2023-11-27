resource "aws_autoscaling_group" "autoscaler" {
  name                      = "m6a-contancts-autoscaler"
  max_size                  = 3
  min_size                  = 1
  health_check_grace_period = 300
  health_check_type         = "ELB"
  desired_capacity          = 2
  force_delete              = true
  target_group_arns = [ aws_lb_target_group.tg.arn ]
  vpc_zone_identifier = aws_lb.app-lb.subnets
  depends_on = [ aws_launch_template.m6a-lt ]
  launch_template {
    id = aws_launch_template.m6a-lt.id
    version = "$Latest"
  }
}


data "aws_ami" "for-ec2ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-kernel-5*"]
  }
}

resource "aws_launch_template" "m6a-lt" {
  name                 = "m6a-contacts-template"
  instance_type        = var.instance_type
  key_name             = var.key_name
  vpc_security_group_ids = [aws_security_group.ec2-sec.id]
  image_id             = data.aws_ami.for-ec2ami.id
  user_data            = filebase64("${path.module}/user-data.sh")
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "Web Server of Contacts App"
    }
  }
  depends_on = [github_repository_file.db_endpoint_file]
}

resource "aws_db_instance" "db-ec2" {
  identifier             = "app-database"
  allocated_storage      = 20
  engine                 = "mysql"
  engine_version         = "8.0.28"
  instance_class         = "db.t2.micro"
  db_name                = "phonebook"
  username               = "admin"
  password               = "m6apassword"
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.db-sec.id]
}

resource "github_repository_file" "db_endpoint_file" {
  content             = aws_db_instance.db-ec2.address
  file                = "dbserver.endpoint"
  repository          = "m6a-contacts"
  branch              = "main"
  overwrite_on_create = true
  commit_message      = "commited by Terraform"
  commit_author       = "Terraform Gods"
  commit_email = "ozgurtaylankarakoc@gmail.com"
}



data "aws_vpc" "default-vpc" {
  default = true
}

data "aws_subnets" "vpc-subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default-vpc.id]
  }
}

resource "aws_lb" "app-lb" {
  name               = "app-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb-sec.id]
  subnets            = data.aws_subnets.vpc-subnets.ids
}

resource "aws_lb_listener" "app-ls" {
  load_balancer_arn = aws_lb.app-lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}
resource "aws_lb_target_group" "tg" {
  name        = "tf-example-lb-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default-vpc.id
  target_type = "instance"
  health_check {
    path                = "/"    # Sağlık kontrolü için yol
    protocol            = "HTTP" # Sağlık kontrolü protokolü (HTTP veya HTTPS)
    port                = "80"   # Hedeflerin bağlantı kurduğu port
    interval            = 30     # Sağlık kontrolü aralığı (saniye cinsinden)
    timeout             = 5      # Sağlık kontrolü zaman aşımı süresi (saniye cinsinden)
    healthy_threshold   = 2      # Hedefin sağlıklı kabul edilmesi için gereken ardışık başarılı sağlık kontrolleri sayısı
    unhealthy_threshold = 3      # Hedefin sağlıksız kabul edilmesi için gereken ardışık başarısız sağlık kontrolleri sayısı
    matcher             = "200"  # Başarılı bir sağlık kontrolü yanıt kodu aralığı
  }
}

output "lb-endpoint" {
  value = "http://${aws_lb.app-lb.dns_name}"
}