
resource "aws_iam_policy" "least_privilege_test" {
  name        = "devsecops-least-privilege-noncompliant"
  description = "Intentionally non-compliant local test fixture"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "*"
      Resource = "*"
    }]
  })
}
