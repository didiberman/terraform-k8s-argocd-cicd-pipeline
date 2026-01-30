resource "aws_iam_user" "github_actions" {
  name = "github-actions-k8s-manager"
}

resource "aws_iam_access_key" "github_actions" {
  user = aws_iam_user.github_actions.name
}

resource "aws_iam_user_policy" "github_actions" {
  name = "k8s-infrastructure-management"
  user = aws_iam_user.github_actions.name

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
      {
        "Effect" : "Allow",
        "Action" : [
          "iam:GetUser",
          "iam:ListAccessKeys",
          "iam:GetUserPolicy",
          "iam:ListUserPolicies",
          "iam:PutUserPolicy",
          "iam:DeleteUserPolicy",
          "iam:DeleteAccessKey"
        ],
        "Resource" : "arn:aws:iam::*:user/github-actions-k8s-manager"
      }
    ]
  })
}

output "github_actions_access_key_id" {
  value = aws_iam_access_key.github_actions.id
}

output "github_actions_secret_access_key" {
  value     = aws_iam_access_key.github_actions.secret
  sensitive = true
}
