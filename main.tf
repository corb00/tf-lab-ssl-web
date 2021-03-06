#1  Create VPC
resource "aws_vpc" "prod" {
  cidr_block = var.vpc_cidr
    tags = {
    Site = "web"
    Name = "prod-vpc"
  }
}

#2  Create subnets, internet gateways, associations
resource "aws_subnet" "private1" {
  vpc_id     = aws_vpc.prod.id
  cidr_block = var.subnet1_cidr
  availability_zone = var.subnet1_az
  tags = {
    Name = "subnet1.private"
    Tier = "private"
    AZ = var.subnet1_az
    }
}
resource "aws_subnet" "private2" {
  vpc_id     = aws_vpc.prod.id
  cidr_block = var.subnet2_cidr
  availability_zone = var.subnet2_az
  tags = {
    Name = "subnet2.private"
    AZ = var.subnet2_az
    Tier = "private"
  }
}

resource "aws_subnet" "public1" {
  vpc_id     = aws_vpc.prod.id
  cidr_block = var.subnetp1_cidr
  availability_zone = var.subnet1_az
  tags = {
    Name = "subnet1.public"
    AZ = var.subnet1_az
    Tier = "public"
  }
}
resource "aws_subnet" "public2" {
  vpc_id     = aws_vpc.prod.id
  cidr_block = var.subnetp2_cidr
  availability_zone = var.subnet2_az
  tags = {
    Name = "subnet2.public"
    AZ = var.subnet2_az
    Tier = "public"
  }
}

# Create Internet gateway, NAT gw + EIP, route tables and all associations
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prod.id
  tags = {
    Name = "public"
  }
}

resource "aws_eip" "nat" {
  vpc = true
}
resource "aws_nat_gateway" "public1" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public1.id

  tags = {
    Name = "NAT gateway"
  }

  depends_on = [aws_internet_gateway.gw]

}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.prod.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  # route {
  #   ipv6_cidr_block        = "::/0"
  #   gateway_id = aws_internet_gateway.gw.id
  # }
  tags = {
    Name = "public-rtable"
  }
}
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.prod.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.public1.id
  }
    tags = {
    Name = "private-rtable"
  }
}

resource "aws_route_table_association" "public1" {
  subnet_id      = aws_subnet.public1.id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table_association" "public2" {
  subnet_id      = aws_subnet.public2.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private1" {
  subnet_id      = aws_subnet.private1.id
  route_table_id = aws_route_table.private.id
}
resource "aws_route_table_association" "private2" {
  subnet_id      = aws_subnet.private2.id
  route_table_id = aws_route_table.private.id
}

#3  Create security groups to allow secure traffic to EC2 from the ALB
resource "aws_security_group" "web" {
  name        = "web"
  description = "secure traffic from ALB"
  vpc_id      = aws_vpc.prod.id
  tags = {
    Name = "ssl_web"
  }
}

resource "aws_security_group" "alb" {
  name = var.alb_security_group_name
  vpc_id      = aws_vpc.prod.id
  tags = {
    Name = "ssl_alb"
  }   
}

resource "aws_security_group_rule" "alb_ingress" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.alb.id
  cidr_blocks              = ["0.0.0.0/0"]
}
resource "aws_security_group_rule" "alb_egress" {
  type                     = "egress"
  from_port                = var.web_server_ssl_port
  to_port                  = var.web_server_ssl_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.alb.id
  source_security_group_id = aws_security_group.web.id
}

resource "aws_security_group_rule" "web_ingress" {
  type                     = "ingress"
  from_port                = var.web_server_ssl_port
  to_port                  = var.web_server_ssl_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.web.id
  source_security_group_id = aws_security_group.alb.id
}
resource "aws_security_group_rule" "web_egress" {
  type                     = "egress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.web.id
  cidr_blocks              = ["0.0.0.0/0"]
}


#4  Create launch configuration
resource "aws_launch_configuration" "as_web" {
  image_id      = var.amis[var.region]
  instance_type = "t2.micro"
  key_name="tf-lab"
  security_groups = [aws_security_group.web.id]
  root_block_device {
    encrypted = true
  }

  user_data = file("end-to-end-ssl.sh")
    
  # Required when using a launch configuration with an auto scaling group. 
  # https://www.terraform.io/docs/providers/aws/r/launch_configuration.html 
  lifecycle {
    create_before_destroy = true
  }
}

#5  Create Autoscaling group
resource "aws_autoscaling_group" "as_web" {
  launch_configuration = aws_launch_configuration.as_web.name
  vpc_zone_identifier  = data.aws_subnet_ids.private.ids

  target_group_arns = [aws_lb_target_group.asg.arn]
  health_check_type = "ELB"

  min_size = 2
  max_size = 2

  tag {
    key                 = "Name"
    value               = "terraform-asg-web"
    propagate_at_launch = true
  }
}

#--------------------------------------------------------------
# Introspection: retrieve public and private subnet id's
# >>> depends_on is NECESSARY to ensure subnets are present
#
data "aws_vpc" "prod" {
   default = false
   id = aws_vpc.prod.id
}
data "aws_subnet_ids" "public" {
  vpc_id = data.aws_vpc.prod.id
  filter {
    name   = "tag:Tier"
    values = ["public"] # insert values here
  } 
  #tags = {
  #  Tier = "public"
  #}
  depends_on = [
    aws_subnet.public1
  ]
}
data "aws_subnet_ids" "private" {
  vpc_id = data.aws_vpc.prod.id
  tags = {
    Tier = "private"
  }
  depends_on = [
    aws_subnet.private1
  ]
}

#-------------------------------------------------------------------

# create Route53 entry, create ACM ssl certificate for test.<domain_name>
# --> validation of certificate


resource "aws_route53_record" "web" {
  zone_id = var.zone_id
  name    = "test.${var.domain_name}"
  type    = "A"
  alias {
    name                   = aws_lb.public_web.dns_name
    zone_id                = aws_lb.public_web.zone_id
    evaluate_target_health = true
  }
}

resource "aws_acm_certificate" "domain" {
  domain_name       = "*.${var.domain_name}"
  validation_method = "DNS"

  tags = {
    Environment = "test"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {

# no SANS -> only one validation record
  count = 1

  zone_id         = var.zone_id
  allow_overwrite = true
  name            = element(aws_acm_certificate.domain.domain_validation_options.*.resource_record_name, count.index)
  type            = element(aws_acm_certificate.domain.domain_validation_options.*.resource_record_type, count.index)
  records         = [element(aws_acm_certificate.domain.domain_validation_options.*.resource_record_value, count.index)]
  ttl             = 60

}

resource "aws_acm_certificate_validation" "domain" {
  certificate_arn         = aws_acm_certificate.domain.arn
  validation_record_fqdns = aws_route53_record.cert_validation.*.fqdn
}

#6  Create ALB
resource "aws_lb" "public_web" {

  name               = var.alb_name

  load_balancer_type = "application"
  subnets            = data.aws_subnet_ids.public.ids
  security_groups    = [aws_security_group.alb.id]
}

#6.1 Create http listener for alb to redirect to https
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.public_web.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

#6.2 Create https Listener - add Listener rule(s)
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.public_web.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn = aws_acm_certificate_validation.domain.certificate_arn
  # By default, return a simple 404 page
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code  = 404
    }
  }
}
resource "aws_lb_listener_rule" "asg" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 100

  condition {
    path_pattern {
      values = ["*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.asg.arn
  }
}

#7  Create Target Group
resource "aws_lb_target_group" "asg" {

  name = var.alb_name

  port     = var.web_server_ssl_port
  protocol = "HTTPS"
  vpc_id   = data.aws_vpc.prod.id

  health_check {
    path                = "/"
    protocol            = "HTTPS"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}
