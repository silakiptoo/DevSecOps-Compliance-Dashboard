
resource "aws_security_group" "ssh_test" {
  name        = "devsecops-ssh-compliant-test"
  description = "Test fixture with restricted SSH and egress"

  ingress {
    description = "SSH from trusted network only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    description = "HTTPS outbound only"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "devsecops-ssh-compliant-test"
    Environment = "test"
  }
}
