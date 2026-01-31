terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "k8s-terraform-state-yadid"
    key            = "telegram-bot/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "k8s-terraform-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = "eu-central-1"
}

# --- Variables ---

variable "telegram_bot_token" {
  type      = string
  sensitive = true
}

variable "github_token" {
  type      = string
  sensitive = true
}

variable "github_repo" {
  type    = string
  default = "yadid/k8s"
}

variable "allowed_username" {
  type = string
}

# --- IAM ---

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "lambda" {
  name = "k8s-telegram-bot-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "ssm_read" {
  name = "ssm-read-k8s"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "ssm:GetParameter"
      Resource = "arn:aws:ssm:eu-central-1:${data.aws_caller_identity.current.account_id}:parameter/k8s/*"
    }]
  })
}

# --- Lambda ---

resource "null_resource" "bot_npm_install" {
  triggers = {
    package_json = filemd5("${path.module}/../package.json")
  }

  provisioner "local-exec" {
    command     = "npm install --omit=dev"
    working_dir = "${path.module}/.."
  }
}

data "archive_file" "bot" {
  type        = "zip"
  source_dir  = "${path.module}/.."
  output_path = "${path.module}/function.zip"
  excludes    = ["infra", "deploy.sh"]

  depends_on = [null_resource.bot_npm_install]
}

resource "aws_lambda_function" "bot" {
  function_name    = "k8s-telegram-bot"
  role             = aws_iam_role.lambda.arn
  handler          = "handler.handler"
  runtime          = "nodejs22.x"
  memory_size      = 128
  timeout          = 30
  filename         = data.archive_file.bot.output_path
  source_code_hash = data.archive_file.bot.output_base64sha256

  environment {
    variables = {
      TELEGRAM_BOT_TOKEN = var.telegram_bot_token
      GITHUB_TOKEN       = var.github_token
      GITHUB_REPO        = var.github_repo
      ALLOWED_USERNAME   = var.allowed_username
    }
  }
}

# --- API Gateway (HTTP API) ---

resource "aws_apigatewayv2_api" "bot" {
  name          = "k8s-telegram-bot"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "bot" {
  api_id                 = aws_apigatewayv2_api.bot.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.bot.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "webhook" {
  api_id    = aws_apigatewayv2_api.bot.id
  route_key = "POST /webhook"
  target    = "integrations/${aws_apigatewayv2_integration.bot.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.bot.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.bot.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.bot.execution_arn}/*/*"
}

# --- Telegram Webhook Registration ---

resource "null_resource" "register_webhook" {
  triggers = {
    webhook_url = "${aws_apigatewayv2_stage.default.invoke_url}/webhook"
  }

  provisioner "local-exec" {
    command = <<-EOT
      curl -sf "https://api.telegram.org/bot${var.telegram_bot_token}/setWebhook?url=${aws_apigatewayv2_stage.default.invoke_url}/webhook"
    EOT
  }

  depends_on = [
    aws_apigatewayv2_route.webhook,
    aws_apigatewayv2_stage.default,
    aws_lambda_permission.apigw
  ]
}

# --- GitHub Actions IAM User (Persistent) ---

# --- GitHub Actions OIDC Configuration ---

# 1. Create the OIDC Provider for GitHub (if not already existing in account)
# Note: If this terraform module is destroyed, it will remove the provider. 
# If you share this account, ensure this doesn't conflict.
data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]
}

# 2. Create the IAM Role that GitHub Actions will assume
resource "aws_iam_role" "github_actions" {
  name = "github-actions-oidc-k8s-manager"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Condition = {
          StringLike = {
            # Allow any branch/tag in this specific repo to assume the role
            "token.actions.githubusercontent.com:sub" : "repo:${var.github_repo}:*"
          }
          StringEquals = {
            "token.actions.githubusercontent.com:aud" : "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

# 3. Attach Permissions to the Role
resource "aws_iam_role_policy" "github_actions" {
  name = "k8s-infrastructure-management-oidc"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Effect" : "Allow",
        "Action" : [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ],
        "Resource" : [
          "arn:aws:s3:::k8s-terraform-state-yadid",
          "arn:aws:s3:::k8s-terraform-state-yadid/*"
        ]
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
          "dynamodb:DescribeTable"
        ],
        "Resource" : "arn:aws:dynamodb:eu-central-1:*:table/k8s-terraform-lock"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "ssm:PutParameter",
          "ssm:GetParameter",
          "ssm:DeleteParameter"
        ],
        "Resource" : "arn:aws:ssm:eu-central-1:*:parameter/k8s/*"
      },
      # Allow managing the bot infrastructure too (Lambda, API Gateway, IAM Roles for Lambda)
      {
        "Effect" : "Allow",
        "Action" : [
          "lambda:*",
          "apigateway:*",
          "iam:PassRole",
          "iam:GetRole",
          "iam:CreateRole",
          "iam:PutRolePolicy",
          "iam:ListRolePolicies",
          "iam:GetRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:DeleteRole",
          # Allow updating this specific role or OIDC provider if needed (careful)
          "iam:GetOpenIDConnectProvider"
        ],
        "Resource" : "*"
      }
    ]
  })
}

# --- Outputs ---

output "github_actions_role_arn" {
  description = "The ARN of the IAM Role to configure in GitHub Actions secrets"
  value       = aws_iam_role.github_actions.arn
}

output "webhook_url" {
  value = "${aws_apigatewayv2_stage.default.invoke_url}/webhook"
}

output "lambda_function_name" {
  value = aws_lambda_function.bot.function_name
}
