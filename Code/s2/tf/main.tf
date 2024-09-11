terraform {
    required_version = "~> 1.0"
}

provider "aws" {
  region  = var.region
  profile = var.aws_profile
}

resource "aws_iam_policy" "policy" {
  name        = "test_policy"
  path        = "/"
  description = "My test policy"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Effect": "Allow",
            "Action": [
                "ec2:DescribeInstances",
                "iam:ListRoles",
                "sts:AssumeRole"
            ],
            "Resource": "*"
      },
    ]
  })
}

resource "aws_iam_group" "developers" {
  name = "Dev"
}
resource "aws_iam_user" "Bob" {
  name = "Bob"

  tags = {
    tag-key = "Valor Tag"
  }
}
resource "aws_iam_user_group_membership" "example1" {
  user = aws_iam_user.Bob.name

  groups = [
    aws_iam_group.developers.name,
  ]
}
resource "aws_iam_group_policy_attachment" "test-attach" {
  group      = aws_iam_group.developers.name
  policy_arn = aws_iam_policy.policy.arn
}

resource "aws_iam_access_key" "Bob" {
  user = aws_iam_user.Bob.name
}

# No se puede almacenar sin ser sensitive
# Esa informacion es almacenado de manera sensible por tanto es necesario obtenerlo desde el State
# terraform output -raw secret_Bob 

output "secret_Bob" {
  value = aws_iam_access_key.Bob.secret
  sensitive = true
}
output "id_Bob" {
  value = aws_iam_access_key.Bob.id
}
output "arn_Bob" {
  value = aws_iam_user.Bob.arn
}
output "tags_Bob" {
  value = aws_iam_user.Bob.tags_all
}
output "unique_id_Bob" {
  value = aws_iam_user.Bob.unique_id
}


resource "aws_iam_role_policy_attachment" "test-attach" {
  role       = aws_iam_role.test_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonRDSReadOnlyAccess"
}

resource "aws_iam_role" "test_role" {
  name = "example-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          AWS = "arn:aws:iam::768312754627:root"
        }
      },
    ]
  })
}

