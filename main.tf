# CREATE VPC
resource "aws_vpc" "duck-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "Duck VPC"
  }
}

# CREATE PRIMARY AND BACKUP SUBNET

resource "aws_subnet" "primary-subnet" {
  vpc_id     = aws_vpc.duck-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "Duck Primary Subnet"
  }
}

resource "aws_subnet" "standby-subnet" {
  vpc_id     = aws_vpc.duck-vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "Duck Standby Subnet"
  }
}

# CREATE SUBNET GROUP

resource "aws_db_subnet_group" "duck-subnet-group" {
  name       = "main"
  subnet_ids = [aws_subnet.primary-subnet.id, aws_subnet.standby-subnet.id]

  tags = {
    Name = "Duck SubnetGroup"
  }
}

# CREATE RDS SECURITY GROUP
resource "aws_security_group" "rds-sg" {
  name        = "rds-security-group"
  description = "Allow RDS connections"
  vpc_id      = aws_vpc.duck-vpc.id

  ingress {
    description      = "RDS Ingress Traffic"
    from_port        = var.port 
    to_port          = var.port  
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 3306 
    to_port          = 3306 
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "rds-sg"
  }
}

# CREATE MULTI-AZ RDS
resource "aws_db_instance" "database" {
  allocated_storage    = 10
  engine               = var.engine
  engine_version       = "5.7"
  instance_class       = "db.m5.large"
  db_name              = var.db_name
  username             = var.username
  password             = var.password 
  db_subnet_group_name = aws_db_subnet_group.duck-subnet-group.name
  vpc_security_group_ids = [aws_security_group.rds-sg.id]
  parameter_group_name = "default.mysql5.7"
  skip_final_snapshot  = true
  multi_az             = true
}

resource "aws_secretsmanager_secret" "rds_secret" {
  name = "duck-rds-proxy-secret-2"
  recovery_window_in_days = 7
  description = "Secret for RDS Proxy"
}

resource "aws_secretsmanager_secret_version" "rds_secret_version" {
  secret_id     = aws_secretsmanager_secret.rds_secret.id
  secret_string = jsonencode({
    "username"             = var.username
    "password"             = var.password
    "engine"               = var.engine
    "host"                 = aws_db_instance.database.address
    "port"                 = var.port
    "dbInstanceIdentifier" = aws_db_instance.database.id
  })
}


resource "aws_db_proxy" "rds_proxy" {
  name = "duck-proxy"
  debug_logging          = false
  engine_family          = upper(var.engine)
  idle_client_timeout    = 1800
  require_tls            = true
  role_arn               = aws_iam_role.rds_proxy_iam_role.arn
  vpc_security_group_ids = [aws_security_group.rds-sg.id]
  vpc_subnet_ids         = aws_db_subnet_group.duck-subnet-group.subnet_ids

  auth {
    auth_scheme = "SECRETS"
    iam_auth    = "REQUIRED"
    secret_arn  = aws_secretsmanager_secret.rds_secret.arn
  }
}

resource "aws_db_proxy_default_target_group" "target" {
  db_proxy_name = aws_db_proxy.rds_proxy.name

  connection_pool_config {
    connection_borrow_timeout    = 120
    max_connections_percent      = 100
  }
}

resource "aws_db_proxy_target" "example" {
  db_instance_identifier = aws_db_instance.database.id
  db_proxy_name          = aws_db_proxy.rds_proxy.name
  target_group_name      = aws_db_proxy_default_target_group.target.name
}
