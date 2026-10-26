resource "aws_iam_policy" "compliant_test" {
  name        = "devsecops-iam-restricted-test"
  description = "Test policy with restricted permissions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject"]
      Resource = ["arn:aws:s3:::devsecops-compliance-test-example/*"]
    }]
  })
}