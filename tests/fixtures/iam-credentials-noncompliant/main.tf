resource "aws_iam_account_password_policy" "noncompliant" {
  minimum_password_length        = 6
  require_lowercase_characters   = false
  require_uppercase_characters   = false
  require_numbers                = false
  require_symbols                = false
  allow_users_to_change_password = true
  password_reuse_prevention      = 0
  max_password_age               = 0
}
