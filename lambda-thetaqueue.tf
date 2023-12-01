# Resources related to thetaqueue

data "aws_iam_policy_document" "deploy_thetaqueue" {
  statement {
    effect = "Allow"

    actions = [
      "s3:PutObject",
      "iam:ListRoles",
      "lambda:UpdateFunctionCode",
      "lambda:CreateFunction",
      "lambda:GetFunction",
      "lambda:UpdateFunctionConfiguration",
      "lambda:GetFunctionConfiguration"
    ]

    resources = [
      aws_lambda_function.thetaqueue.arn
    ]
  }
}

resource "aws_iam_role" "deploy_thetaqueue" {
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Federated" : "arn:aws:iam::911986281031:oidc-provider/token.actions.githubusercontent.com"
        },
        "Action" : "sts:AssumeRoleWithWebIdentity",
        "Condition" : {
          "StringEquals" : {
            "token.actions.githubusercontent.com:aud" : "sts.amazonaws.com"
          },
          "StringLike" : {
            "token.actions.githubusercontent.com:sub" : "repo:major/thetaqueue:*"
          }
        }
      }
    ]
  })

  inline_policy {
    name   = "deploy_thetaqueue"
    policy = data.aws_iam_policy_document.deploy_thetaqueue.json
  }

  description          = "Deploy thetaqueue lambda from GitHub Actions"
  max_session_duration = "3600"
  name                 = "deploy_thetaqueue"
  path                 = "/"
}

data "aws_iam_policy_document" "thetaqueue" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "thetaqueue" {
  name               = "thetaqueue"
  assume_role_policy = data.aws_iam_policy_document.thetaqueue.json
}

data "archive_file" "thetaqueue" {
  type        = "zip"
  source_file = "lambda_bootstrap/lambda.py"
  output_path = "bootstrap.zip"
}

resource "aws_lambda_function" "thetaqueue" {
  filename      = "bootstrap.zip"
  function_name = "thetaqueue"
  description   = "Lambda function for thetaqueue"
  role          = aws_iam_role.thetaqueue.arn
  handler       = "lambda.run"
  timeout       = "15"

  # depends_on = [aws_cloudwatch_log_group.thetaqueue_log_group]

  source_code_hash = data.archive_file.thetaqueue.output_base64sha256

  runtime = "python3.11"

  environment {
    variables = {
      foo = "bar"
    }
  }
}

# Eventbridge/Cloudwatch schedule trigger
resource "aws_cloudwatch_event_rule" "thetaqueue" {
  name                = "every-five-minutesthetaqueue"
  description         = "Run thetaqueue lambda"
  schedule_expression = "rate(60 minutes)"
}

resource "aws_cloudwatch_event_target" "thetaqueue" {
  rule      = aws_cloudwatch_event_rule.thetaqueue.name
  target_id = "thetaqueue"
  arn       = aws_lambda_function.thetaqueue.arn
}

resource "aws_lambda_permission" "thetaqueue" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.thetaqueue.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.thetaqueue.arn
}

# Logging
resource "aws_iam_policy" "thetaqueue_logging_policy" {
  name = "function-logging-policy"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        Action : [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect : "Allow",
        Resource : "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "thetaqueue_logging_policy_attachment" {
  role       = aws_iam_role.thetaqueue.id
  policy_arn = aws_iam_policy.thetaqueue_logging_policy.arn
}

resource "aws_cloudwatch_log_group" "thetaqueue_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.thetaqueue.function_name}"
  retention_in_days = 7
  lifecycle {
    prevent_destroy = false
  }
}
