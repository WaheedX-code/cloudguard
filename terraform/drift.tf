# Scheduled drift check: CodeBuild clones the repo, runs terraform plan
# read-only, and publishes to the security-alerts topic when it finds drift.

resource "aws_cloudwatch_log_group" "drift_check" {
  name              = "/codebuild/${var.environment_name}-drift-check"
  retention_in_days = 30
}

resource "aws_iam_role" "drift_check" {
  name = "${var.environment_name}-drift-check"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "codebuild.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "drift_check_readonly" {
  role       = aws_iam_role.drift_check.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy" "drift_check_extra" {
  name = "publish-and-log"
  role = aws_iam_role.drift_check.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "sns:Publish"
        Resource = aws_sns_topic.security_alerts.arn
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "${aws_cloudwatch_log_group.drift_check.arn}:*"
      }
    ]
  })
}

resource "aws_codebuild_project" "drift_check" {
  name          = "${var.environment_name}-drift-check"
  service_role  = aws_iam_role.drift_check.arn
  build_timeout = 15

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:7.0"
    type         = "LINUX_CONTAINER"

    environment_variable {
      name  = "REPO_URL"
      value = "https://github.com/WaheedX-code/cloudguard.git"
    }
    environment_variable {
      name  = "SNS_TOPIC_ARN"
      value = aws_sns_topic.security_alerts.arn
    }
  }

  source {
    type      = "NO_SOURCE"
    buildspec = file("${path.module}/drift-buildspec.yml")
  }

  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.drift_check.name
    }
  }
}

resource "aws_iam_role" "drift_events" {
  name = "${var.environment_name}-drift-events"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "drift_events_start" {
  name = "start-drift-build"
  role = aws_iam_role.drift_events.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "codebuild:StartBuild"
      Resource = aws_codebuild_project.drift_check.arn
    }]
  })
}

# Hourly while testing so a scheduled run shows up quickly; switch to
# rate(1 day) once the evidence is captured.
resource "aws_cloudwatch_event_rule" "drift_schedule" {
  name                = "${var.environment_name}-drift-check"
  schedule_expression = "rate(1 hour)"
}

resource "aws_cloudwatch_event_target" "drift_check" {
  rule     = aws_cloudwatch_event_rule.drift_schedule.name
  arn      = aws_codebuild_project.drift_check.arn
  role_arn = aws_iam_role.drift_events.arn
}
