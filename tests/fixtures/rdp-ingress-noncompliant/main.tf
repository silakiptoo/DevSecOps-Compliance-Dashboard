
resource "aws_security_group" "rdp_test" {
  name        = "devsecops-rdp-noncompliant-test"
  description = "Test fixture with unrestricted RDP"

  ingress {
    description = "Intentionally insecure RDP test"
    from_port   = 3389
    to_port     = 3389
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
    Name        = "devsecops-rdp-noncompliant-test"
    Environment = "test"
  }
}
