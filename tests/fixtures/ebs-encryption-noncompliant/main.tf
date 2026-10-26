resource "aws_ebs_volume" "noncompliant_test" {
  availability_zone = "us-east-1a"
  size              = 1
  encrypted         = false

  tags = {
    Name = "devsecops-ebs-noncompliant-test"
  }
}