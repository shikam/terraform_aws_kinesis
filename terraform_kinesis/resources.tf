provider "aws" {
  access_key = "<ENTER ACCESS KEY>"
  secret_key = "<ENTER SECRET KEY>"
  region     = "us-east-1"
}

//create data stream
resource "aws_kinesis_stream" "directeam_stream" {
  name             = "terraform-kinesis-directeam-yagel"
  shard_count      = 1
  retention_period = 30

  shard_level_metrics = [
    "IncomingBytes",
    "OutgoingBytes",
  ]

  tags = {
    Environment = "directeam"
  }
}

//create iam admin role for firehose
resource "aws_iam_role" "admin-access-role" {
    name = "AdminAccessRole"

assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "firehose.amazonaws.com"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "sts:ExternalId":"${var.aws_account_id}"
        }
      }
    }
  ]

}
EOF


}

//attach the admin iam, to administrator roles 
resource "aws_iam_role_policy_attachment" "admin-access-policy" {
    role = "${aws_iam_role.admin-access-role.name}"
    policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

//create elasticsearch domain
resource "aws_elasticsearch_domain" "directeam_cluster" {
  domain_name = "${var.domain}"
  elasticsearch_version = "6.4"
    cluster_config {
    instance_type = "t2.small.elasticsearch"
  }
  ebs_options{
    ebs_enabled = true
    volume_size = 10
  }


access_policies = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "es:*",
            "Principal": "*",
            "Effect": "Allow",
            "Resource": "arn:aws:es:us-east-1:${var.aws_account_id}:domain/${var.domain}/*"
        }
    ]
}
POLICY




  depends_on = [
    "aws_iam_service_linked_role.es",
  ]
}

//give the iam access to es service
resource "aws_iam_service_linked_role" "es" {
  aws_service_name = "es.amazonaws.com"
}

//define the elasticsearch domain policy
resource "aws_elasticsearch_domain_policy" "main" {
  domain_name = "${var.domain}"

  access_policies = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": [
          "*"
        ]
      },
      "Action": [
        "es:*"
      ],
      "Resource": "arn:aws:es:us-east-1:${var.aws_account_id}:domain/${aws_elasticsearch_domain.directeam_cluster.arn}/*"
    }
  ]
}
EOF
}


//create iam role for rirehose
resource "aws_iam_role" "firehose_role" {
  name = "firehose_directeam_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "firehose.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

//define policy for iam role
resource "aws_iam_role_policy" "inline-policy" {
  name   = "firehose_yagel_inline_policy"
  role   = "${aws_iam_role.firehose_role.id}"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:AbortMultipartUpload",
        "s3:GetBucketLocation",
        "s3:GetObject",
        "s3:ListBucket",
        "s3:ListBucketMultipartUploads",
        "s3:PutObject"
      ],
      "Resource": [
        "${aws_s3_bucket.bucket.arn}",
        "${aws_s3_bucket.bucket.arn}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "kinesis:DescribeStream",
        "kinesis:GetShardIterator",
        "kinesis:GetRecords"
      ],
      "Resource": "${aws_kinesis_stream.directeam_stream.arn}"
    }
  ]
}
EOF
}

//define s3 bucket for failed requests
resource "aws_s3_bucket" "bucket" {
  bucket = "tf-directeam-yagel-bucket"
  acl    = "private"
}

//create firehose delivery stream
resource "aws_kinesis_firehose_delivery_stream" "directeam_stream" {
  name        = "terraform-kinesis-firehose-yagel-stream"
  destination = "elasticsearch"

  //config the source of firehose
  kinesis_source_configuration {
    kinesis_stream_arn = "${aws_kinesis_stream.directeam_stream.arn}"
    role_arn           = "${aws_iam_role.firehose_role.arn}"
  }

  //config the s3 connected to firehose
  s3_configuration {
    role_arn           = "${aws_iam_role.firehose_role.arn}"
    bucket_arn         = "${aws_s3_bucket.bucket.arn}"
    buffer_size        = 10
    buffer_interval    = 400
    compression_format = "GZIP"
  }

  //config where to send the data to (elasticsearch)
  elasticsearch_configuration {
    domain_arn = "${aws_elasticsearch_domain.directeam_cluster.arn}"
    //role_arn   = ["${aws_iam_role.firehose_role.arn}", "${aws_iam_role.admin-access-role.arn}"]
    role_arn   = "${aws_iam_role.admin-access-role.arn}"
    index_name = "directeam"
    type_name  = "directeam"
  }
}

