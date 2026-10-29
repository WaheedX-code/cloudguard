# Chain B, Project 6: this was the seeded finding. The key policy used to grant
# kms:Decrypt and kms:GenerateDataKey to the account root, which hands the
# decision to any IAM principal in the account. It now names who may use the key.
resource "aws_kms_key" "uploads_encryption" {
  description             = "Encrypts objects in the uploads bucket"
  deletion_window_in_days = 7

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "KeyAdministrationNoDataUse"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action = [
          "kms:CreateAlias", "kms:Describe*", "kms:Enable*", "kms:List*", "kms:Put*",
          "kms:Update*", "kms:Revoke*", "kms:Disable*", "kms:Get*", "kms:Delete*",
          "kms:TagResource", "kms:UntagResource", "kms:ScheduleKeyDeletion", "kms:CancelKeyDeletion"
        ]
        Resource = "*"
      },
      {
        Sid       = "UploadFunctionUsesKeyViaS3"
        Effect    = "Allow"
        Principal = { AWS = aws_iam_role.lambda_process_upload.arn }
        Action    = ["kms:Decrypt", "kms:GenerateDataKey"]
        Resource  = "*"
        Condition = { StringEquals = { "kms:ViaService" = "s3.us-east-1.amazonaws.com" } }
      },
      {
        Sid       = "MacieDecryptsForClassification"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/macie.amazonaws.com/AWSServiceRoleForAmazonMacie" }
        Action    = ["kms:Decrypt"]
        Resource  = "*"
      },
      {
        Sid       = "DeployUserTestUploadsOnly"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/cloudguard@deploy" }
        Action    = ["kms:GenerateDataKey"]
        Resource  = "*"
        Condition = { StringEquals = { "kms:ViaService" = "s3.us-east-1.amazonaws.com" } }
      }
    ]
  })
}

resource "aws_kms_alias" "uploads_encryption" {
  name          = "alias/${var.environment_name}-uploads"
  target_key_id = aws_kms_key.uploads_encryption.key_id
}
