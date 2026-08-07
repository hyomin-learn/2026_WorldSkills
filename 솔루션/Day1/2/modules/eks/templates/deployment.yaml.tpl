apiVersion: apps/v1
kind: Deployment
metadata:
  name: book
  namespace: wskorea26
  labels:
    app: book
spec:
  replicas: 2
  selector:
    matchLabels:
      app: book
  template:
    metadata:
      labels:
        app: book
    spec:
      serviceAccountName: book-sa
      nodeSelector:
        node-type: app
      tolerations:
        - key: node-type
          value: app
          effect: NoSchedule
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: topology.kubernetes.io/zone
          whenUnsatisfiable: ScheduleAnyway
          labelSelector:
            matchLabels:
              app: book
      containers:
        - name: book
          image: ${image}
          imagePullPolicy: Always
          ports:
            - containerPort: 8080
          env:
            - name: AWS_REGION
              value: "ap-northeast-2"
            - name: TABLE_NAME
              value: "${table_name}"
          readinessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 15
          resources:
            requests: { cpu: "100m", memory: "128Mi" }
            limits:   { cpu: "500m", memory: "256Mi" }
---
apiVersion: v1
kind: Service
metadata:
  name: book-svc
  namespace: wskorea26
  labels:
    app: book
spec:
  type: NodePort
  selector:
    app: book
  ports:
    - name: http
      port: 80
      targetPort: 8080
      nodePort: ${node_port}
      protocol: TCP
