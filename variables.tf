variable "region" {
  default = "us-west-2"
}

variable "zone_id" {
  description = "The existing zone ID of the target domains hosted zone"
  type        = string
  default     = "Z03882723NVM0WRQ836HN"
}

variable "domain_name" {
  description = "Domain name to be used for the site"
  type        = string
  default     = "domain123.com"
}

variable "vpc_cidr" {
  type = string
  default = "10.0.0.0/16"
}

variable "subnet1_cidr" {
  type = string
  default = "10.0.1.0/24"
}
variable "subnet1_az" {
  type = string
  default = "us-west-2a"
}
variable "subnet2_cidr" {
  type = string
  default = "10.0.2.0/24"
}
variable "subnet2_az" {
  type = string
  default = "us-west-2b"
}
variable "subnetp1_cidr" {
  type = string
  default = "10.0.4.0/24"
}
variable "subnetp2_cidr" {
  type = string
  default = "10.0.5.0/24"
}

variable "amis" {
  type = map(string)
  default = {
    "us-east-1" = "ami-0885b1f6bd170450c"
    "us-west-2" = "ami-07dd19a7900a1f049"
  }
}

variable "web_server_ssl_port" {
  type = number
  default = 443
}



variable "alb_name" {
  description = "The name of the ALB"
  type        = string
  default     = "terraform-asg"
}

variable "instance_security_group_name" {
  description = "The name of the security group for the EC2 Instances"
  type        = string
  default     = "terraform-web_server"
}

variable "alb_security_group_name" {
  description = "The name of the security group for the ALB"
  type        = string
  default     = "terraform-alb"
}
