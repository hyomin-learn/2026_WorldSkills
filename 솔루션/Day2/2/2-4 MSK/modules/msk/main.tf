resource "aws_msk_configuration" "this" {
  name              = "${var.project}-msk-config"
  kafka_versions    = [var.kafka_version]
  server_properties = <<-PROPERTIES
    auto.create.topics.enable=true
    default.replication.factor=2
    num.partitions=3
    min.insync.replicas=1
  PROPERTIES
}

resource "aws_msk_cluster" "this" {
  cluster_name           = "${var.project}-msk-cluster"
  kafka_version          = var.kafka_version
  number_of_broker_nodes = var.broker_count

  configuration_info {
    arn      = aws_msk_configuration.this.arn
    revision = aws_msk_configuration.this.latest_revision
  }

  broker_node_group_info {
    instance_type   = var.instance_type
    client_subnets  = var.private_subnet_ids
    security_groups = [var.security_group_id]

    storage_info {
      ebs_storage_info {
        volume_size = 100
      }
    }
  }

  client_authentication {
    sasl {
      iam = true
    }
    unauthenticated = true
  }

  encryption_info {
    encryption_in_transit {
      client_broker = "TLS_PLAINTEXT"
      in_cluster    = true
    }
  }

  tags = {
    Name = "${var.project}-msk-cluster"
  }
}
