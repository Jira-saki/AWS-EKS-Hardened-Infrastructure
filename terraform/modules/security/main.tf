# WAF for ALB
resource "aws_wafv2_web_acl" "alb_waf" {
  #checkov:skip=CKV2_AWS_31: "WAF logging configuration disabled to reduce CloudWatch ingestion cost in lab"
  name        = "alb-waf-${var.cluster_name}"
  description = "WAF for EKS ALB"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  # Rule 1: Common Rule Set
  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  # Rule 2: Known Bad Inputs (Log4j / Protection)
  rule {
    name     = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesKnownBadInputsMetric"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "alb-waf-metric"
    sampled_requests_enabled   = true
  }
}

# GuardDuty
resource "aws_guardduty_detector" "primary" {
  #checkov:skip=CKV2_AWS_3: "Single-account standalone GuardDuty deployment used for lab"
  enable = true
}

resource "aws_guardduty_detector_feature" "eks_runtime_monitoring" {
  detector_id = aws_guardduty_detector.primary.id
  name        = "EKS_RUNTIME_MONITORING"
  status      = "ENABLED"

  additional_configuration {
    name   = "EKS_ADDON_MANAGEMENT"
    status = "ENABLED"
  }
}

# ALB Security Group
resource "aws_security_group" "alb_sg" {
  #checkov:skip=CKV2_AWS_5: "Security group attached dynamically to ALB resource via ingress controller"
  #checkov:skip=CKV_AWS_260: "HTTP port 80 ingress required for HTTP to HTTPS redirect on ALB"
  #checkov:skip=CKV_AWS_382: "Full outbound egress allowed for ALB target group forwarding"

  name        = "alb-sg-${var.cluster_name}"
  description = "Security Group for Application Load Balancer"
  vpc_id      = var.vpc_id

  #checkov:skip=CKV_AWS_260: "HTTP port 80 ingress required for HTTP to HTTPS redirect on ALB"
  ingress {
    description = "HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from Internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #checkov:skip=CKV_AWS_382: "Full outbound egress allowed for ALB target group forwarding"
  egress {
    description = "Allow all outbound traffic to target groups"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    #trivy:ignore:AWS-0104
    cidr_blocks = ["0.0.0.0/0"]
  }
}
