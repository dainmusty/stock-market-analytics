resource "aws_db_instance" "postgres" {
  identifier              = var.identifier
  engine                  = var.db_engine
  engine_version          = var.db_engine_version
  instance_class          = var.instance_class
  allocated_storage       = var.allocated_storage
  db_name                 = var.db_name
  username                = var.username
  password                = var.password
  vpc_security_group_ids  = var.vpc_security_group_ids
  db_subnet_group_name    = aws_db_subnet_group.rds_subnet_group.name
  multi_az                = var.multi_az
  storage_type            = var.storage_type
  backup_retention_period = var.backup_retention_period
  skip_final_snapshot     = var.skip_final_snapshot
  publicly_accessible     = var.publicly_accessible
  tags                    = var.db_tags
}

resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "${var.env}-${var.db_subnet_group_name}"
  subnet_ids = var.subnet_ids
  tags = {
    Name = "${var.env}-rds-subnet-group"
  }
}

# ElastiCache (Memcached) Setup
resource "aws_elasticache_subnet_group" "memcached" {
  name       = "${var.env}-memcached-subnets"
  subnet_ids = var.subnet_ids
}

resource "aws_elasticache_cluster" "memcached" {
  cluster_id           = "${var.env}-memcached"
  engine               = "memcached"
  node_type            = var.node_type 
  num_cache_nodes      = var.num_cache_nodes  # one per AZ
  parameter_group_name = "default.memcached1.6"
  port                 = 11211
  subnet_group_name    = aws_elasticache_subnet_group.memcached.name
  security_group_ids   = var.cache_sg_ids 
}
