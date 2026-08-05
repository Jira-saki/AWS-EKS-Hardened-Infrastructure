output "alb_sg_id" {
  value = aws_security_group.alb_sg.id
}

output "waf_web_acl_arn" {
  value = aws_wafv2_web_acl.alb_waf.arn
}
