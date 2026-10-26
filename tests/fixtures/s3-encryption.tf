resource "aws_s3_bucket" "compliant_test" {
  bucket = "devsecops-compliance-test-example"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "compliant_test" {
  bucket = aws_s3_bucket.compliant_test.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "compliant_test" {
  bucket = aws_s3_bucket.compliant_test.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}