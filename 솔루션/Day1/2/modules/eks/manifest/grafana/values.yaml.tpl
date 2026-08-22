adminUser: '${grafana_admin_user}'
adminPassword: '${grafana_admin_password}'
nodeSelector:
  node-type: addon
service:
  type: NodePort
  port: 80
  nodePort: ${grafana_node_port}
persistence:
  enabled: false
initChownData:
  enabled: false
serviceAccount:
  create: true
  name: grafana
grafana.ini:
  server:
    root_url: "%(protocol)s://%(domain)s/"
datasources:
  datasources.yaml:
    apiVersion: 1
    datasources:
      - name: Prometheus
        uid: prometheus
        type: prometheus
        access: proxy
        url: http://prometheus-server.monitoring.svc
        isDefault: true