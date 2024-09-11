#Adaptado de https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket


output "bucket_source_of_replication" {
  value = aws_s3_bucket.source.bucket_regional_domain_name
}
output "bucket_destination_of_replication" {
  value = aws_s3_bucket.destination.bucket_regional_domain_name
}

provider "aws" {
  alias  = "central"
  region = "eu-central-1"
}
provider "aws" {
  alias  = "west"
  region = "us-west-1"
}

resource "aws_iam_role" "replication" {
  name = "tf-iam-role-replication-12345"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "s3.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
POLICY
}

resource "aws_iam_policy" "replication" {
  name = "tf-iam-role-policy-replication-12345"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:GetReplicationConfiguration",
        "s3:ListBucket"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_s3_bucket.source.arn}"
      ]
    },
    {
      "Action": [
        "s3:GetObjectVersionForReplication",
        "s3:GetObjectVersionAcl",
         "s3:GetObjectVersionTagging"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_s3_bucket.source.arn}/*"
      ]
    },
    {
      "Action": [
        "s3:ReplicateObject",
        "s3:ReplicateDelete",
        "s3:ReplicateTags"
      ],
      "Effect": "Allow",
      "Resource": "${aws_s3_bucket.destination.arn}/*"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "replication" {
  role       = aws_iam_role.replication.name
  policy_arn = aws_iam_policy.replication.arn
}

resource "aws_s3_bucket" "destination" {
  bucket = var.destination_bucket
}

resource "aws_s3_bucket_versioning" "destination" {
  bucket = aws_s3_bucket.destination.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket" "source" {
  provider = aws.central
  bucket   = var.source_bucket
}


resource "aws_s3_bucket_versioning" "source" {
  provider = aws.central

  bucket = aws_s3_bucket.source.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_replication_configuration" "replication" {
  provider = aws.central
  # Must have bucket versioning enabled first
  depends_on = [aws_s3_bucket_versioning.source]

  role   = aws_iam_role.replication.arn
  bucket = aws_s3_bucket.source.id

  rule {
    id = "replicationconfigurationrule"
    priority = 5
    delete_marker_replication {
      status = "Enabled"
    }

    filter {
      prefix = "" #Para que sean todos los elementos para la replicacion
    }

    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.destination.arn
      storage_class = "STANDARD"
    }
  }
}

resource "aws_s3_object" "sample1" {
  provider     = aws.central
  key          = "AWS_SAA_C02_Labs-Labs3c1.jpg"
  bucket       = aws_s3_bucket.source.id
  source       = "../AWS_SAA_C02_Labs-Labs3c1.jpg"
  content_type = "image/jpg"
  etag         = filemd5("../AWS_SAA_C02_Labs-Labs3c1.jpg")
}
resource "aws_s3_object" "sample2" {
  provider     = aws.central
  key          = "AWS_SAA_C02_Labs-Labs3c2.jpg"
  bucket       = aws_s3_bucket.source.id
  source       = "../AWS_SAA_C02_Labs-Labs3c2.jpg"
  content_type = "image/jpg"
  etag         = filemd5("../AWS_SAA_C02_Labs-Labs3c2.jpg")
}
