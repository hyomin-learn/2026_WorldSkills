data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name

  glue_db_arn     = "arn:aws:glue:${local.region}:${local.account_id}:database/${var.glue_database_name}"
  glue_tables_arn = "arn:aws:glue:${local.region}:${local.account_id}:table/${var.glue_database_name}/*"
  glue_catalog    = "arn:aws:glue:${local.region}:${local.account_id}:catalog"
  flink_log_group = "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/kinesis-analytics/*"
}

# =====================================================================
# 6-A. EC2 Role  (wsc2026-alaytics-ec2-role)
#   NOTE: 과제 문서 표기 그대로 'alaytics' 사용(오타로 추정).
#         철자를 고치려면 아래 name 두 곳을 wsc2026-analytics-ec2-role 로 변경.
#   권한: SSM 접속 + Kinesis 로 주문 로그 적재(PutRecord/PutRecords)만 허용
# =====================================================================
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2" {
  name               = "${var.project}-alaytics-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
  tags               = { Name = "${var.project}-alaytics-ec2-role" }
}

# SSM Session Manager 접속용 관리형 정책
resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Kinesis 쓰기 (해당 스트림으로 한정 - 최소 권한)
data "aws_iam_policy_document" "ec2_kinesis_put" {
  statement {
    sid    = "KinesisProduce"
    effect = "Allow"
    actions = [
      "kinesis:PutRecord",
      "kinesis:PutRecords",
      "kinesis:DescribeStream",
      "kinesis:DescribeStreamSummary",
      "kinesis:ListShards",
    ]
    resources = [var.stream_arn]
  }
}

resource "aws_iam_role_policy" "ec2_kinesis_put" {
  name   = "${var.project}-analytics-ec2-kinesis-put"
  role   = aws_iam_role.ec2.id
  policy = data.aws_iam_policy_document.ec2_kinesis_put.json
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project}-analytics-ec2-profile"
  role = aws_iam_role.ec2.name
  tags = { Name = "${var.project}-analytics-ec2-profile" }
}

# =====================================================================
# 6-B. Managed Flink Role  (wsc2026-analytics-flink-role)
#   권한: Kinesis 읽기 + Glue Data Catalog(Studio 필수) + CloudWatch Logs
# =====================================================================
data "aws_iam_policy_document" "flink_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["kinesisanalytics.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "flink" {
  name               = "${var.project}-analytics-flink-role"
  assume_role_policy = data.aws_iam_policy_document.flink_assume.json
  tags               = { Name = "${var.project}-analytics-flink-role" }
}

data "aws_iam_policy_document" "flink_policy" {
  # Kinesis 소스 스트림 읽기 (해당 스트림 한정)
  statement {
    sid    = "KinesisConsume"
    effect = "Allow"
    actions = [
      "kinesis:DescribeStream",
      "kinesis:DescribeStreamSummary",
      "kinesis:GetShardIterator",
      "kinesis:GetRecords",
      "kinesis:ListShards",
      "kinesis:SubscribeToShard",
      "kinesis:DescribeStreamConsumer",
      "kinesis:RegisterStreamConsumer",
      "kinesis:DeregisterStreamConsumer",
    ]
    resources = [
      var.stream_arn,
      "${var.stream_arn}/*",
    ]
  }

  # Studio Notebook 이 사용하는 Glue Data Catalog
  statement {
    sid    = "GlueCatalog"
    effect = "Allow"
    actions = [
      "glue:GetConnection",
      "glue:GetDatabase",
      "glue:GetDatabases",
      "glue:CreateDatabase",
      "glue:GetTable",
      "glue:GetTables",
      "glue:CreateTable",
      "glue:UpdateTable",
      "glue:DeleteTable",
      "glue:GetPartition",
      "glue:GetPartitions",
      "glue:BatchGetPartition",
      "glue:CreatePartition",
      "glue:GetUserDefinedFunction",
      "glue:GetUserDefinedFunctions",
    ]
    resources = [
      local.glue_catalog,
      local.glue_db_arn,
      local.glue_tables_arn,
    ]
  }

  # 애플리케이션 로깅
  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]
    resources = [local.flink_log_group]
  }
}

resource "aws_iam_role_policy" "flink_policy" {
  name   = "${var.project}-analytics-flink-policy"
  role   = aws_iam_role.flink.id
  policy = data.aws_iam_policy_document.flink_policy.json
}
