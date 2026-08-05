locals {
  topic_arn_prefix   = replace(var.msk_cluster_arn, ":cluster/", ":topic/")
  raw_topic_arn      = "${local.topic_arn_prefix}/${var.raw_topic_name}"
  alert_topic_arn    = "${local.topic_arn_prefix}/${var.alert_topic_name}"
  group_wildcard_arn = "${replace(var.msk_cluster_arn, ":cluster/", ":group/")}/*"
}

data "archive_file" "sensor_consumer" {
  type        = "zip"
  source_dir  = "${path.module}/src/sensor_consumer"
  output_path = "${path.module}/build/sensor_consumer.zip"
}

data "archive_file" "alert_consumer" {
  type        = "zip"
  source_dir  = "${path.module}/src/alert_consumer"
  output_path = "${path.module}/build/alert_consumer.zip"
}

resource "aws_iam_role" "lambda_role" {
  name = "${var.project}-msk-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "vpc_access" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "lambda_msk_access" {
  name = "${var.project}-msk-lambda-msk-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "MskCluster"
        Effect   = "Allow"
        Action   = ["kafka-cluster:Connect", "kafka-cluster:DescribeCluster", "kafka-cluster:DescribeClusterDynamicConfiguration"]
        Resource = var.msk_cluster_arn
      },
      {
        Sid      = "MskReadRaw"
        Effect   = "Allow"
        Action   = ["kafka-cluster:ReadData", "kafka-cluster:DescribeTopic"]
        Resource = local.raw_topic_arn
      },
      {
        Sid      = "MskReadAlert"
        Effect   = "Allow"
        Action   = ["kafka-cluster:ReadData", "kafka-cluster:DescribeTopic"]
        Resource = local.alert_topic_arn
      },
      {
        Sid      = "MskWriteAlert"
        Effect   = "Allow"
        Action   = ["kafka-cluster:WriteData"]
        Resource = local.alert_topic_arn
      },
      {
        Sid      = "MskGroup"
        Effect   = "Allow"
        Action   = ["kafka-cluster:AlterGroup", "kafka-cluster:DescribeGroup"]
        Resource = local.group_wildcard_arn
      },
      {
        Sid    = "MskControlPlane"
        Effect = "Allow"
        Action = [
          "kafka:DescribeCluster",
          "kafka:DescribeClusterV2",
          "kafka:GetBootstrapBrokers"
        ]
        Resource = "*"
      },
      {
        Sid    = "VpcDescribeForEventSourceMapping"
        Effect = "Allow"
        Action = [
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcs"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_data_access" {
  name = "${var.project}-msk-lambda-data-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DynamoDbWrite"
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem", "dynamodb:GetItem"]
        Resource = var.dynamodb_table_arn
      },
      {
        Sid      = "SnsPublish"
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = var.sns_topic_arn
      },
      {
        Sid      = "S3PutAlertLog"
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = "${var.s3_bucket_arn}/alert/*"
      }
    ]
  })
}

resource "aws_lambda_function" "sensor_consumer" {
  function_name = "${var.project}-sensor-consumer"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = var.runtime
  timeout       = 30
  memory_size   = 256

  filename         = data.archive_file.sensor_consumer.output_path
  source_code_hash = data.archive_file.sensor_consumer.output_base64sha256

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.security_group_id]
  }

  environment {
    variables = {
      DDB_TABLE        = var.dynamodb_table_name
      ALERT_TOPIC      = var.alert_topic_name
      BOOTSTRAP_SERVER = var.msk_bootstrap_brokers_iam
    }
  }

  tags = {
    Name = "${var.project}-sensor-consumer"
  }
}

resource "aws_lambda_function" "alert_consumer" {
  function_name = "${var.project}-sensor-alert-consumer"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = var.runtime
  timeout       = 30
  memory_size   = 256

  filename         = data.archive_file.alert_consumer.output_path
  source_code_hash = data.archive_file.alert_consumer.output_base64sha256

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.security_group_id]
  }

  environment {
    variables = {
      SNS_TOPIC_ARN = var.sns_topic_arn
      S3_BUCKET     = var.s3_bucket_name
    }
  }

  tags = {
    Name = "${var.project}-sensor-alert-consumer"
  }
}

resource "aws_lambda_event_source_mapping" "sensor_raw" {
  event_source_arn  = var.msk_cluster_arn
  function_name     = aws_lambda_function.sensor_consumer.arn
  topics            = [var.raw_topic_name]
  starting_position = "TRIM_HORIZON"
  batch_size        = 100
  enabled           = true

  amazon_managed_kafka_event_source_config {
    consumer_group_id = "${var.project}-sensor-consumer-group"
  }
}

resource "aws_lambda_event_source_mapping" "sensor_alert" {
  event_source_arn  = var.msk_cluster_arn
  function_name     = aws_lambda_function.alert_consumer.arn
  topics            = [var.alert_topic_name]
  starting_position = "TRIM_HORIZON"
  batch_size        = 100
  enabled           = true

  amazon_managed_kafka_event_source_config {
    consumer_group_id = "${var.project}-sensor-alert-consumer-group"
  }
}
