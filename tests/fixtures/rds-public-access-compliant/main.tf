
resource "aws_db_instance" "private_access_test" {
  identifier             = "devsecops-rds-private-test"
  engine                 = "postgres"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  username               = "testadmin"
  password               = "TemporaryTestPassword123!"
  skip_final_snapshot    = true
  publicly_accessible    = false
  storage_encrypted      = true
}
