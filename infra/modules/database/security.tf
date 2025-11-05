# Security Group for RDS
resource "aws_security_group" "db" {
  name        = "${var.project_name}-${var.environment}-db-sg"
  description = "Security group for LogLine RDS PostgreSQL"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project_name}-${var.environment}-db-sg"
  }
}

# Allow PostgreSQL access from Lambda security group (will be created later)
resource "aws_security_group_rule" "db_ingress_lambda" {
  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  security_group_id = aws_security_group.db.id

  # This will be populated when we create Lambda security group
  # For now, allow from the VPC CIDR (tighten in production)
  cidr_blocks = [data.aws_vpc.main.cidr_block]

  description = "Allow PostgreSQL access from VPC"
}

# Optional: Allow access from specific CIDR blocks (e.g., your IP for debugging)
resource "aws_security_group_rule" "db_ingress_cidr" {
  count = length(var.allowed_cidr_blocks) > 0 ? 1 : 0

  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  security_group_id = aws_security_group.db.id
  cidr_blocks       = var.allowed_cidr_blocks

  description = "Allow PostgreSQL access from allowed CIDR blocks"
}

# Egress (RDS needs to connect out for replication, backups, etc.)
resource "aws_security_group_rule" "db_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.db.id
  cidr_blocks       = ["0.0.0.0/0"]

  description = "Allow all outbound traffic"
}

# Data source for VPC info
data "aws_vpc" "main" {
  id = var.vpc_id
}

# Security Group for Lambda functions (to be used later)
resource "aws_security_group" "lambda" {
  name        = "${var.project_name}-${var.environment}-lambda-sg"
  description = "Security group for LogLine Lambda functions"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-lambda-sg"
  }
}

# Allow Lambda to connect to RDS
resource "aws_security_group_rule" "lambda_to_db" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.db.id
  source_security_group_id = aws_security_group.lambda.id

  description = "Allow Lambda functions to connect to RDS"
}
