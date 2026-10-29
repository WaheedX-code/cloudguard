# Uploads one object into the legacy_exports bucket containing
# sensitive-SHAPED data for DSPM discovery, built entirely from
# industry-standard, safe, non-functional test values:
#   - Visa's own published test card number (4111111111111111),
#     recognized worldwide as non-functional test data
#   - An SSA-documented never-issued SSN pattern (area number 900,
#     which the Social Security Administration has never assigned)
#   - AWS's own published example access key
#     (AKIAIOSFODNN7EXAMPLE), already used the same way in DocuTrust
# None of this is real, sensitive, or functional. It is shaped to be
# FOUND by a classifier, not to BE anything real.
resource "aws_s3_object" "dspm_seed_finding" {
  bucket = aws_s3_bucket.legacy_exports.id
  key    = "2019-customer-export/partial_records.csv"

  content = <<-CSV
    record_id,note,test_card_number,test_ssn,legacy_integration_key
    1,"sample record left over from a 2019 migration, never cleaned up",4111111111111111,900-00-1234,AKIAIOSFODNN7EXAMPLE
  CSV

  content_type           = "text/csv"
  server_side_encryption = "aws:kms"
  kms_key_id             = aws_kms_key.uploads_encryption.arn
}
