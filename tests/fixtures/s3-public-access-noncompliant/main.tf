resource "aws_s3_bucket" "public_access_test" {
  bucket = "devsecops-public-access-noncompliant-example"
}

resource "aws_s3_bucket_public_access_block" "public_access_test" {
  bucket = aws_s3_bucket.public_access_test.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}
