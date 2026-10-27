resource "aws_iam_role" "cartography_read" {
  name        = "${var.environment_name}-cartography-read"
  description = "Read-only role for Cartography ingest runs from the deploy user's workstation."

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/cloudguard@deploy" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cartography_read" {
  role       = aws_iam_role.cartography_read.name
  policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"
}
