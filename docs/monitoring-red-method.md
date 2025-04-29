# Student API Monitoring Guide - RED Method Implementation

## Introduction

The Student API implements monitoring following the RED Method (Rate, Errors, Duration), a monitoring philosophy created by Tom Wilkie that focuses on key metrics that directly impact user experience.

## RED Method Implementation

### Rate (Requests per Second)

We track request rates through several metrics:

```promql
# Overall request rate
sum(rate(http_request_duration_seconds_count{namespace="student-api"}[5m]))

# Request rate by endpoint
sum(rate(student_api_requests_total{path="/api/students"}[5m]))
sum(rate(student_api_requests_total{path="/api/courses"}[5m]))
```

**Alert Rules**:

- High traffic alert when request rate exceeds normal baseline
- Low traffic alert for unexpected drops in request rate

### Errors (Failed Requests)

Error tracking focuses on both system and application-level errors:

```promql
# Error rate as percentage
sum(rate(http_server_errors_total[5m])) / sum(rate(http_requests_total[5m]))

# Absolute error count
sum(student_api_errors_total)
```

**Alert Rules**:

- HighErrorRate: Triggers when error rate exceeds 5% over 2 minutes
- DatabaseConnectionIssues: Triggers when database connectivity drops

### Duration (Request Latency)

Latency monitoring covers various percentiles:

```promql
# 95th percentile latency by endpoint
histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket{namespace="student-api"}[5m])) by (le, path))

# Average response time
sum(rate(student_api_response_time_seconds_sum[5m])) / sum(rate(student_api_response_time_seconds_count[5m]))
```

**Alert Rules**:

- HighLatency: Triggers when p95 latency exceeds 1 second

## Monitoring Stack Components

### Metrics Collection

- Prometheus server scrapes metrics every 30s
- Metric endpoints exposed on `/metrics`
- Service discovery via pod annotations

### Visualization

- Grafana dashboards with RED Method panels
- Pre-configured alerts based on RED thresholds
- Custom dashboards for deeper analysis

### Alerting

- Alert rules defined in `grafana-alert-rules.yaml`
- Notifications via multiple channels (email, Discord)
- Alert grouping by severity and team

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
