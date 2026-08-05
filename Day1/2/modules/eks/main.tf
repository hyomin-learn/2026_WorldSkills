# EKS 클러스터 + book 애플리케이션 + 모니터링(Prometheus/Grafana/Fluent Bit) 배포.
# bastion(SSH)에 파일을 업로드하고 원격으로 eksctl/kubectl/helm 을 실행한다.

resource "null_resource" "bootstrap" {
  triggers = {
    bastion_id       = var.bastion_instance_id
    cluster_yaml_sha = sha256(templatefile("${path.module}/templates/cluster.yaml.tpl", {
      vpc_id             = var.vpc_id
      priv_subnet_c_id   = var.private_subnet_ids["c"]
      priv_subnet_d_id   = var.private_subnet_ids["d"]
      eks_key_arn        = var.eks_key_arn
      node_extra_sg_id   = var.node_extra_sg_id
    }))
    cluster_up_sha = sha256(templatefile("${path.module}/templates/cluster-up.sh.tpl", {
      bastion_sg_id         = var.bastion_sg_id
      vpc_environment_sg_id = var.vpc_environment_sg_id
    }))
    kube_apps_sha = sha256(templatefile("${path.module}/templates/kube-apps.sh.tpl", {
      ecr_repo_url              = var.ecr_repo_url
      ecr_repo_name             = var.ecr_repo_name
      book_write_policy_arn     = var.book_write_policy_arn
      book_target_group_arn     = var.book_target_group_arn
      grafana_target_group_arn  = var.grafana_target_group_arn
    }))
    book_image_sha = sha256(join("", [
      filesha256("${path.module}/book/Dockerfile"),
      filesha256("${path.module}/book/book"),
    ]))
    manifests_sha = sha256(join("", [
      templatefile("${path.module}/manifest/grafana/values.yaml.tpl", {
        grafana_admin_user     = var.grafana_admin_user
        grafana_admin_password = var.grafana_admin_password
        grafana_node_port      = var.grafana_node_port
      }),
      filesha256("${path.module}/manifest/grafana/configmap.yaml"),
      filesha256("${path.module}/manifest/prometheus/values.yaml"),
      filesha256("${path.module}/manifest/fluent-bit/values.yaml"),
    ]))
  }

  connection {
    type        = "ssh"
    host        = var.bastion_public_ip
    user        = "ec2-user"
    private_key = var.bastion_private_key_pem
    timeout     = "10m"
  }

  provisioner "remote-exec" {
    inline = [
      "cloud-init status --wait || true",
      "mkdir -p /home/ec2-user/eks/manifest/book /home/ec2-user/eks/manifest/grafana /home/ec2-user/eks/manifest/prometheus /home/ec2-user/eks/manifest/fluent-bit /home/ec2-user/eks/scripts /home/ec2-user/eks/book",
    ]
  }

  provisioner "file" {
    source      = "${path.module}/book/"
    destination = "/home/ec2-user/eks/book"
  }

  provisioner "file" {
    source      = "${path.module}/manifest/grafana/configmap.yaml"
    destination = "/home/ec2-user/eks/manifest/grafana/configmap.yaml"
  }

  provisioner "file" {
    source      = "${path.module}/manifest/prometheus/values.yaml"
    destination = "/home/ec2-user/eks/manifest/prometheus/values.yaml"
  }

  provisioner "file" {
    source      = "${path.module}/manifest/fluent-bit/values.yaml"
    destination = "/home/ec2-user/eks/manifest/fluent-bit/values.yaml"
  }

  provisioner "file" {
    content = templatefile("${path.module}/templates/deployment.yaml.tpl", {
      image      = "${var.ecr_repo_url}:stable"
      table_name = var.table_name
      node_port  = var.book_node_port
    })
    destination = "/home/ec2-user/eks/manifest/book/deployment.yaml"
  }

  provisioner "file" {
    content = templatefile("${path.module}/manifest/grafana/values.yaml.tpl", {
      grafana_admin_user     = var.grafana_admin_user
      grafana_admin_password = var.grafana_admin_password
      grafana_node_port      = var.grafana_node_port
    })
    destination = "/home/ec2-user/eks/manifest/grafana/values.yaml"
  }

  provisioner "file" {
    content = templatefile("${path.module}/templates/cluster.yaml.tpl", {
      vpc_id           = var.vpc_id
      priv_subnet_c_id = var.private_subnet_ids["c"]
      priv_subnet_d_id = var.private_subnet_ids["d"]
      eks_key_arn      = var.eks_key_arn
      node_extra_sg_id = var.node_extra_sg_id
    })
    destination = "/home/ec2-user/eks/cluster.yaml"
  }

  provisioner "file" {
    content = templatefile("${path.module}/templates/cluster-up.sh.tpl", {
      bastion_sg_id         = var.bastion_sg_id
      vpc_environment_sg_id = var.vpc_environment_sg_id
    })
    destination = "/home/ec2-user/eks/scripts/cluster-up.sh"
  }

  provisioner "file" {
    content = templatefile("${path.module}/templates/kube-apps.sh.tpl", {
      ecr_repo_url            = var.ecr_repo_url
      ecr_repo_name           = var.ecr_repo_name
      book_write_policy_arn   = var.book_write_policy_arn
      book_target_group_arn   = var.book_target_group_arn
      grafana_target_group_arn = var.grafana_target_group_arn
    })
    destination = "/home/ec2-user/eks/scripts/kube-apps.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sed -i 's/\\r$//' /home/ec2-user/eks/scripts/*.sh",
      "chmod +x /home/ec2-user/eks/scripts/*.sh",
      "export PATH=/usr/local/bin:/usr/local/sbin:$PATH",
      "sudo env \"PATH=$PATH\" bash /home/ec2-user/eks/scripts/cluster-up.sh",
      "sudo env \"PATH=$PATH\" bash /home/ec2-user/eks/scripts/kube-apps.sh",
    ]
  }
}
