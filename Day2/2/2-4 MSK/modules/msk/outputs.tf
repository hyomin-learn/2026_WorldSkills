output "cluster_arn" {
  value = aws_msk_cluster.this.arn
}

output "cluster_name" {
  value = aws_msk_cluster.this.cluster_name
}

output "bootstrap_brokers_iam" {
  value = aws_msk_cluster.this.bootstrap_brokers_sasl_iam
}

output "bootstrap_brokers_plaintext" {
  value = aws_msk_cluster.this.bootstrap_brokers
}
