resource "aws_macie2_classification_job" "daily_scan" {
  job_type            = "SCHEDULED"
  name                = "cloudguard-p5-daily-scan"
  description         = "Daily scan of uploads, legacy_exports and lambda_artifacts with the CloudGuard custom identifiers"
  initial_run         = false
  sampling_percentage = 100

  custom_data_identifier_ids = [
    aws_macie2_custom_data_identifier.aws_access_key_id.id,
    aws_macie2_custom_data_identifier.ssn_shaped.id,
    aws_macie2_custom_data_identifier.visa_shaped.id,
  ]

  schedule_frequency {
    daily_schedule = true
  }

  s3_job_definition {
    bucket_definitions {
      account_id = data.aws_caller_identity.current.account_id
      buckets = [
        aws_s3_bucket.uploads.id,
        aws_s3_bucket.legacy_exports.id,
        aws_s3_bucket.lambda_artifacts.id,
      ]
    }
  }

  depends_on = [aws_macie2_account.main]
}
