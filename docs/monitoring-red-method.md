# Student API Monitoring Guide - RED Method Implementation

## Introduction

The Student API implements monitoring following the RED Method (Rate, Errors, Duration), a monitoring philosophy created by Tom Wilkie that focuses on key metrics that directly impact user experience.

## RED Method Implementation

### Rate (Requests per Second)

We track request rates using standardized metrics:

```promql
# Overall request rate
sum(rate(student_api_requests_rate_total{namespace="student-api"}[5m]))

# Request rate by endpoint and method
sum(rate(student_api_requests_rate_total{namespace="student-api"}[5m])) by (path, method)

# Traffic pattern analysis
topk(5, sum(rate(student_api_requests_rate_total{namespace="student-api"}[5m])) by (path))
```

**Alert Rules**:

- HighTrafficRate: Triggers when request rate exceeds 1000 req/s
- LowTrafficRate: Triggers when request rate drops below baseline

### Errors (Failed Requests)

Error tracking uses consistent error-specific metrics:

```promql
# Error rate as percentage
sum(rate(student_api_errors_total{namespace="student-api"}[5m])) / sum(rate(student_api_requests_rate_total{namespace="student-api"}[5m]))

# Error breakdown by type
sum(student_api_errors_total) by (error_type, path)

# Failed requests by status code
sum(rate(student_api_errors_total{namespace="student-api"}[5m])) by (status_code)
```

**Alert Rules**:

- HighErrorRate: Triggers when error rate exceeds 5%
- ErrorSpike: Triggers on sudden increase in error rate
- DatabaseErrors: Triggers on persistent database errors

### Duration (Request Latency)

Latency monitoring uses consistent duration metrics:

```promql
# 95th percentile latency by endpoint
histogram_quantile(0.95, sum(rate(student_api_duration_seconds_bucket{namespace="student-api"}[5m])) by (le, path))

# Average response time by endpoint
sum(rate(student_api_duration_seconds_sum{namespace="student-api"}[5m])) by (path) / sum(rate(student_api_duration_seconds_count{namespace="student-api"}[5m])) by (path)

# Latency breakdown by path and method
histogram_quantile(0.99, sum(rate(student_api_duration_seconds_bucket{namespace="student-api"}[5m])) by (le, path, method))
```

**Alert Rules**:

- HighLatency: Triggers when p95 latency exceeds 1s
- LatencySpike: Triggers on sudden latency increases
- EndpointSlowdown: Triggers when specific endpoints slow down

## Monitoring Stack Components

### Metrics Collection

- Prometheus server scrapes metrics every 30s
- All metrics follow standard label patterns:
  - `namespace`: Service namespace (e.g., "student-api")
  - `service`: Service name (e.g., "api", "postgres", "nginx")
  - `endpoint`: API endpoint path (e.g., "/api/v1/students")
  - `method`: HTTP method (e.g., "GET", "POST")
  - `status_code`: HTTP response code
  - `version`: Service version/tag

### Visualization

- Unified Grafana dashboards with consistent labels
- Metric grouping by service, endpoint, and status
- Label-based filtering and aggregation
- Custom dashboards leveraging standardized labels

### Alerting

- Alert rules use consistent label matching:

```yaml
labels:
  severity: [critical|warning|info]
  service: [api|postgres|nginx]
  team: [sre|dev|ops]
  environment: [prod|dev|staging]
```

- Notifications routed based on severity and team labels
- Alert grouping using service and environment labels

## Access and Usage

### Prometheus Access

```bash
kubectl port-forward svc/prometheus-nodeport -n observability 9090:9090
```

### Grafana Access

```bash
kubectl port-forward svc/grafana-nodeport -n observability 3000:3000
# Default login: admin/admin
```

### Testing RED Metrics

Generate test traffic:

```bash
# Basic health check
curl http://localhost:8080/health

# Generate API traffic
curl http://localhost:8080/api/v1/students
```

## Dashboard Guide

The Student API dashboard is organized around the RED Method:

1. **Rate Panels**

   - "Total API Requests" - Current request rate
   - "Requests by Path" - Traffic distribution

2. **Error Panels**

   - "HTTP Error Rate" - Percentage of failing requests
   - "Error Count by Type" - Error distribution

3. **Duration Panels**
   - "HTTP Request Duration (p95)" - Latency trends
   - "Response Time Heatmap" - Latency distribution

## Alert Configuration

Example alert rule (from grafana-alert-rules.yaml):

```yaml
- alert: HighErrorRate
  expr: sum(rate(http_server_errors_total[5m])) / sum(rate(http_requests_total[5m])) > 0.05
  for: 2m
  labels:
    severity: warning
    team: sre
  annotations:
    summary: "High HTTP error rate"
    description: "Student API error rate is above 5%"
```

## Troubleshooting

1. **Missing Metrics**

   ```bash
   # Verify metrics endpoint is accessible
   kubectl port-forward svc/student-api -n student-api 8080:8080
   curl http://localhost:8080/metrics
   ```

2. **High Error Rates**

   ```bash
   # Check recent error logs
   kubectl logs -n student-api -l app=student-api --tail=100
   ```

3. **Latency Issues**
   ```bash
   # Check database connection metrics
   kubectl port-forward -n student-api pod/<postgres-pod> 9187:9187
   curl http://localhost:9187/metrics | grep pg_stat_activity
   ```

## References

- [RED Method by Tom Wilkie](https://grafana.com/blog/2018/08/02/the-red-method-how-to-instrument-your-services/)
- [Prometheus Documentation](https://prometheus.io/docs/introduction/overview/)
- [Grafana Documentation](https://grafana.com/docs/)
