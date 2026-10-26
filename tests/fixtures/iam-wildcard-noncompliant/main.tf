resource "aws_iam_policy" "noncompliant_test" {
  name        = "devsecops-iam-wildcard-test"
  description = "Local test fixture with overly broad permissions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "*"
      Resource = "*"
    }]
  })
}