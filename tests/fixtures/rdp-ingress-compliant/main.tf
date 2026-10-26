

resource "aws_security_group" "rdp_test" {
  name        = "devsecops-rdp-compliant-test"
  description = "Test fixture with RDP restricted to a trusted network"

  ingress {
    description = "RDP from trusted network only"
    from_port   = 3389
    to_port     = 3389
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
    Name        = "devsecops-rdp-compliant-test"
    Environment = "test"
  }
}
