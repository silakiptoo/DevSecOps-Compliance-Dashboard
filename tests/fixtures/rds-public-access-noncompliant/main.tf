
resource "aws_db_instance" "public_access_test" {
  identifier             = "devsecops-rds-public-test"
  engine                 = "postgres"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  username               = "testadmin"
  password               = "TemporaryTestPassword123!"
  skip_final_snapshot    = true
  publicly_accessible    = true
  storage_encrypted      = true
}
