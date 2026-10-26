resource "aws_ebs_volume" "compliant_test" {
  availability_zone = "us-east-1a"
  size              = 1
  encrypted         = true

  tags = {
    Name = "devsecops-ebs-compliant-test"
  }
}