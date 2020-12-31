#8 Outputs
output "Load_Balancer_public_DNS_name" {
    value = aws_lb.public_web.dns_name
 }