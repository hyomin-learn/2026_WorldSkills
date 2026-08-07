# =====================================================================
# 5. Managed Apache Flink - Studio Notebook
#    Application : wsc2026-analytics-flink
#
#  [중요] runtime_environment 에 대한 주의
#  ---------------------------------------------------------------
#  과제 문서는 "Runtime: Apache Flink 1.19" 로 명시되어 있으나,
#  Managed Flink "Studio Notebook"(Zeppelin/INTERACTIVE)은 현재
#  ZEPPELIN-FLINK-3_0 (= Flink 1.15) 까지만 지원한다.
#  (1.18/1.19/1.20 용 Zeppelin Flink Interpreter 미출시 - AWS 공식)
#  과제의 핵심 요구사항이 "Studio Notebook + SQL 쿼리, Flink 앱
#  프로그래밍 금지" 이므로 Studio 로 구현하며 런타임은 변수로 분리했다.
#  채점 환경이 ZEPPELIN-FLINK 신버전을 지원하면 변수만 교체하면 된다.
#
#  또한 application_mode = "INTERACTIVE" 와 zeppelin 카탈로그 설정은
#  표준 hashicorp/aws provider 미지원이라 awscc provider 를 사용한다.
# =====================================================================

# Studio Notebook 이 메타데이터(테이블 정의)를 저장할 Glue Data Catalog DB
resource "aws_glue_catalog_database" "studio" {
  name = var.glue_database_name
}

# IAM 역할의 신뢰 정책이 STS 에 전파될 시간을 확보한다.
# awscc(Cloud Control API)는 역할 assume 실패 시 자동 재시도하지 않으므로,
# 역할 생성 직후 곧바로 앱을 만들면 다음 오류가 발생한다:
#   "Kinesis Analytics service doesn't have sufficient privileges to assume the role"
resource "time_sleep" "wait_for_role" {
  create_duration = var.role_propagation_delay

  triggers = {
    role_arn = var.service_execution_role
  }
}

resource "awscc_kinesisanalyticsv2_application" "studio" {
  application_name       = "${var.project}-analytics-flink"
  runtime_environment    = var.runtime_environment
  application_mode       = "INTERACTIVE"
  service_execution_role = var.service_execution_role

  depends_on = [time_sleep.wait_for_role]

  application_configuration = {
    flink_application_configuration = {
      parallelism_configuration = {
        configuration_type  = "CUSTOM"
        parallelism         = 1
        parallelism_per_kpu = 1
      }
    }
    zeppelin_application_configuration = {
      catalog_configuration = {
        glue_data_catalog_configuration = {
          database_arn = aws_glue_catalog_database.studio.arn
        }
      }
    }
  }
}
