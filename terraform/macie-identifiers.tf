resource "aws_macie2_custom_data_identifier" "aws_access_key_id" {
  name        = "cloudguard-aws-access-key-id"
  description = "AWS access key ID shape (AKIA or ASIA prefix), no secret key required"
  regex       = "(AKIA|ASIA)[A-Z0-9]{16}"
  depends_on  = [aws_macie2_account.main]
}

resource "aws_macie2_custom_data_identifier" "ssn_shaped" {
  name        = "cloudguard-ssn-shaped"
  description = "SSN-shaped value, including area numbers the built-in identifier rejects"
  regex       = "[0-9]{3}-[0-9]{2}-[0-9]{4}"
  depends_on  = [aws_macie2_account.main]
}

resource "aws_macie2_custom_data_identifier" "visa_shaped" {
  name        = "cloudguard-visa-shaped"
  description = "Visa-shaped 16 digit number, no keyword required"
  regex       = "4[0-9]{15}"
  depends_on  = [aws_macie2_account.main]
}
