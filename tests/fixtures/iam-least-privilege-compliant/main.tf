
resource "aws_iam_policy" "least_privilege_test" {
  name        = "devsecops-least-privilege-compliant"
  description = "Allow only the required S3 read actions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject"]
      Resource = "arn:aws:s3:::devsecops-test-bucket/*"
    }]
  })
}
