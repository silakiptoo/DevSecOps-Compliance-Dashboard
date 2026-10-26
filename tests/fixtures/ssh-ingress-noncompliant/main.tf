
resource "aws_security_group" "ssh_test" {
  name        = "devsecops-ssh-noncompliant-test"
  description = "Test fixture intentionally allowing SSH from anywhere"

  ingress {
    description = "INTENTIONALLY INSECURE: SSH open to all IPv4 addresses"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "HTTPS outbound only"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "devsecops-ssh-noncompliant-test"
    Environment = "test"
  }
}
