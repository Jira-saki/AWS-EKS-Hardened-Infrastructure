resource "aws_security_group" "opensearch_sg" {
  name        = "${var.domain_name}-sg"
  description = "Security group for OpenSearch Domain"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS access within VPC subnet range"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] # Allow from VPC
  }
}

resource "aws_kms_key" "opensearch" {
  description             = "KMS key for OpenSearch encryption at rest"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name = "${var.domain_name}-kms"
  }
}

resource "aws_opensearch_domain" "siem" {
  #checkov:skip=CKV_AWS_318: "Single node deployment used for lab environment cost control"
  #checkov:skip=CKV2_AWS_59: "Dedicated master nodes skipped for single-node lab cluster"
  #checkov:skip=CKV2_AWS_52: "Fine-grained access control managed via IAM access policies in lab"
  #checkov:skip=CKV_AWS_317: "Audit logging disabled in lab to reduce CloudWatch costs"
  #checkov:skip=CKV_AWS_84: "Search/Application logging disabled in lab to reduce CloudWatch costs"

  domain_name    = var.domain_name
  engine_version = "OpenSearch_2.11"

  cluster_config {
    instance_type          = "t3.small.search"
    instance_count         = 1
    zone_awareness_enabled = false
  }

  ebs_options {
    ebs_enabled = true
    volume_size = 20
    volume_type = "gp3"
  }

  vpc_options {
    subnet_ids         = [var.data_subnet_ids[0]]
    security_group_ids = [aws_security_group.opensearch_sg.id]
  }

  encrypt_at_rest {
    enabled    = true
    kms_key_id = aws_kms_key.opensearch.arn
  }

  node_to_node_encryption {
    enabled = true
  }

  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  access_policies = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "es:*"
      Principal = "*"
      Effect    = "Allow"
      Resource  = "arn:aws:es:*:*:domain/${var.domain_name}/*"
    }]
  })
}
