# The application's real data bucket. Public access is blocked at the
# account and bucket level everywhere in this environment by default,
# any exposure findings later projects surface should come from IAM or
# bucket policy misconfiguration, not from skipping this baseline.
resource "aws_s3_bucket" "uploads" {
  bucket = "${var.environment_name}-uploads-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_public_access_block" "uploads" {
  bucket                  = aws_s3_bucket.uploads.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "uploads" {
  bucket = aws_s3_bucket.uploads.id
  versioning_configuration {
    status = "Enabled"
  }
}

# SEEDED FINDING for Chain B, Project 5 (CWPP and DSPM): a bucket
# containing sensitive-shaped data that nobody has ever classified or
# inventoried, exactly the "forgotten bucket" scenario DSPM tooling
# exists to catch. The object uploaded into it (see
# terraform/dspm-seed-data.tf) uses only industry-standard, safe test
# values, Visa's own published test card number and an SSA-documented
# never-issued SSN pattern, shaped like real sensitive data for a
# scanner to find, never actually sensitive or functional.
resource "aws_s3_bucket" "legacy_exports" {
  bucket = "${var.environment_name}-legacy-exports-${data.aws_caller_identity.current.account_id}"
  tags = {
    DataClassification = "sensitive"
    ClassifiedBy       = "macie"
  }
}

resource "aws_s3_bucket_public_access_block" "legacy_exports" {
  bucket                  = aws_s3_bucket.legacy_exports.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Bucket for Lambda deployment packages.
resource "aws_s3_bucket" "lambda_artifacts" {
  bucket = "${var.environment_name}-lambda-artifacts-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_public_access_block" "lambda_artifacts" {
  bucket                  = aws_s3_bucket.lambda_artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
