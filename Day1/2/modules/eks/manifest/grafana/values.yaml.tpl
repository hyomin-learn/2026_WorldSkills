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
dashboardProviders:
  dashboardproviders.yaml:
    apiVersion: 1
    providers:
      - name: wskorea26
        orgId: 1
        folder: ""
        type: file
        disableDeletion: false
        editable: true
        options:
          path: /var/lib/grafana/dashboards/wskorea26
dashboardsConfigMaps:
  wskorea26: grafana-wskorea26-dashboard
