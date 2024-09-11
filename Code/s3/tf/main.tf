# Adaptado de https://www.alexhyett.com/terraform-s3-static-website-hosting
# Principalmente de https://github.com/alexhyett/terraform-s3-static-website/blob/main/src/s3.tf
# Actualizado 2024 de https://medium.com/@frankpromiseedah/hosting-a-static-website-on-aws-s3-using-terraform-e12addd22d18
terraform {
  required_version = "~> 1.00"

  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
  # Aqui hacemos el ejemplo de tener un backend remoto y la importancia de tenerlo en un Object Storage
  backend "s3" {
    bucket = "franciscomoreno"
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region  = var.region
  profile = var.aws_profile
}
resource "aws_s3_bucket" "bucket-1" {
  bucket = "www.${var.bucketname}"
}
data "aws_s3_bucket" "selected-bucket" {
  bucket = aws_s3_bucket.bucket-1.bucket
}
resource "aws_s3_bucket_acl" "bucket-acl" {
  bucket = data.aws_s3_bucket.selected-bucket.id
  acl    = "public-read"
  depends_on = [aws_s3_bucket_ownership_controls.s3_bucket_acl_ownership]
}
resource "aws_s3_bucket_ownership_controls" "s3_bucket_acl_ownership" {
  bucket = data.aws_s3_bucket.selected-bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
  depends_on = [aws_s3_bucket_public_access_block.example]
}

resource "aws_s3_bucket_public_access_block" "example" {
  bucket = data.aws_s3_bucket.selected-bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "bucket-policy" {
  bucket = data.aws_s3_bucket.selected-bucket.id
  policy = data.aws_iam_policy_document.iam-policy-1.json
}
data "aws_iam_policy_document" "iam-policy-1" {
  statement {
    sid    = "AllowPublicRead"
    effect = "Allow"
resources = [
      "arn:aws:s3:::www.${var.bucketname}",
      "arn:aws:s3:::www.${var.bucketname}/*",
    ]
actions = ["S3:GetObject"]
principals {
      type        = "*"
      identifiers = ["*"]
    }
  }

  depends_on = [aws_s3_bucket_public_access_block.example]
}
resource "aws_s3_bucket_website_configuration" "website-config" {
  bucket = data.aws_s3_bucket.selected-bucket.bucket
index_document {
    suffix = "index.html"
  }
error_document {
    key = "error.html"
  }

}
resource "aws_s3_object" "index_document" {
  key          = "index.html"
  bucket       = aws_s3_bucket.bucket-1.id
  source       = "../CLI/src/index.html"
  content_type = "text/html"
  etag         = filemd5("../CLI/src/index.html")
}
resource "aws_s3_object" "error_document" {
  key          = "error.html"
  bucket       = aws_s3_bucket.bucket-1.id
  source       = "../CLI/src/error.html"
  content_type = "text/html"
  etag         = filemd5("../CLI/src/error.html")
}

output "bucket" {
  value = "http://${aws_s3_bucket_website_configuration.website-config.website_endpoint}"
}