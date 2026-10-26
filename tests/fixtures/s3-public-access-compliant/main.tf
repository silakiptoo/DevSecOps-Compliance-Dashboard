resource "aws_s3_bucket" "public_access_test" {
  bucket = "devsecops-public-access-test-example"
}

resource "aws_s3_bucket_public_access_block" "public_access_test" {
  bucket = aws_s3_bucket.public_access_test.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}