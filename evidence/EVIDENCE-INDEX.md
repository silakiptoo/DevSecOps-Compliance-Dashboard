# DevSecOps Continuous Compliance Framework - Evidence Index

| Policy ID | Control | Checkov Rule(s) | Compliant Evidence | Non-Compliant Evidence |
|---|---|---|---|---|
| ENC-001 | S3 encryption using KMS | CKV_AWS_145 | evidence/s3-encryption-compliant/results.json | evidence/s3-encryption-noncompliant/results.json |
| ENC-002 | EBS encryption | CKV_AWS_3 | evidence/ebs-encryption-compliant/results_json.json | evidence/ebs-encryption-noncompliant/results_json.json |
| ENC-003 | RDS encryption | CKV_AWS_16 | evidence/rds-encryption-compliant/results_json.json | evidence/rds-encryption-noncompliant/results_json.json |
| NET-001 | SSH ingress restriction | CKV_AWS_24 | evidence/ssh-ingress-compliant/results_json.json | evidence/ssh-ingress-noncompliant/results.json |
| NET-002 | RDP ingress restriction | CKV_AWS_25 | evidence/rdp-ingress-compliant-results.json | evidence/rdp-ingress-noncompliant-results.json |
| NET-003 | RDS public access restriction | CKV_AWS_17 | evidence/rds-public-access-compliant-results.json | evidence/rds-public-access-noncompliant-results.json |
| IAM-001 | Wildcard permissions | CKV_AWS_355 | evidence/iam-wildcard-compliant/results_json.json | evidence/iam-wildcard-noncompliant/results_json.json |
| IAM-002 | Least privilege | CKV_AWS_63, CKV_AWS_355 | evidence/iam-least-privilege-compliant-results.json | evidence/iam-least-privilege-noncompliant-results.json |
| IAM-003 | IAM password complexity | CKV_AWS_14, CKV_AWS_15 | evidence/iam-password-policy-compliant.json | evidence/iam-password-policy-noncompliant.json |

## Notes
- JSON reports contain Checkov static-analysis results for local Terraform fixtures.
- Compliant fixtures should pass the selected checks; non-compliant fixtures should fail them.
- IAM-003 tests IAM password symbol and uppercase requirements. The separate root-access-key check CKV_AWS_348 is not counted as a passing test because the compliant fixture had zero applicable results.
- S3 public-access protection is an additional control; its reports are stored under the s3-public-access evidence folders.
- These local tests do not prove controls have been deployed to or validated in AWS.
