output "cluster_endpoint" {
  value = aws_docdb_cluster.this.endpoint
}

output "cluster_port" {
  value = aws_docdb_cluster.this.port
}

output "cluster_id" {
  value = aws_docdb_cluster.this.id
}
