# Student API Monitoring Guide - USE Method Implementation

## Introduction

This document outlines how the Student API implements monitoring following the USE Method (Utilization, Saturation, Errors), a methodology developed by Brendan Gregg for analyzing system performance by examining resources. This approach complements our existing RED Method monitoring.

## What is the USE Method?

The USE Method directs analysis at the utilization, saturation, and errors of all system resources:

- **Utilization**: The percentage of time the resource is busy servicing work
- **Saturation**: The degree to which a resource has extra work it can't service (queue length or wait time)
- **Errors**: The count of error events or failures

## Resources Monitored

We monitor the following resources using the USE Method:

### Hardware Resources

1. **CPU**
   - Utilization: CPU usage percentage
   - Saturation: Run queue length or scheduler latency
   - Errors: CPU hardware errors (if detectable)

2. **Memory**
   - Utilization: Memory usage percentage
   - Saturation: Swap usage or OOM events
   - Errors: Memory errors (if detectable)

3. **Network Interfaces**
   - Utilization: Network bandwidth usage
   - Saturation: Packet drops or TCP retransmits
   - Errors: Network interface errors

4. **Storage I/O**
   - Utilization: Disk I/O utilization
   - Saturation: Disk I/O queue depth
   - Errors: Disk errors

### Software Resources

1. **Container Resources**
   - Utilization: Container CPU/memory limits usage
   - Saturation: Container throttling events
   - Errors: Container restarts/failures

2. **Kubernetes Resources**
   - Utilization: Node and pod resource usage
   - Saturation: Pod pending status, resource pressure
   - Errors: Pod failures, evictions

## USE Method Implementation

### CPU Metrics

```promql
# Utilization - CPU utilization by node (percentage)
100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Saturation - System load averages
node_load1, node_load5, node_load15

# Saturation - Process run queue length
node_procs_running - 1

# Errors - CPU hardware errors (if supported)
node_cpu_core_throttles_total
```

### Memory Metrics

```promql
# Utilization - Memory usage percentage
100 * (1 - ((node_memory_MemFree_bytes + node_memory_Cached_bytes + node_memory_Buffers_bytes) / node_memory_MemTotal_bytes))

# Saturation - Anonymous paging or swapping activity
rate(node_vmstat_pgpgin[5m]) + rate(node_vmstat_pgpgout[5m])

# Saturation - OOM kills
rate(node_vmstat_oom_kill[5m])

# Errors - Memory allocation failures (if available)
node_memory_numa_allocation_failures_total
```

### Network Interface Metrics

```promql
# Utilization - Network throughput vs capacity
rate(node_network_transmit_bytes_total[5m]) / node_network_speed_bytes

# Saturation - Network interface packet drops
rate(node_network_receive_drop_total[5m]) + rate(node_network_transmit_drop_total[5m])

# Errors - Network interface errors
rate(node_network_receive_errs_total[5m]) + rate(node_network_transmit_errs_total[5m])
```

### Storage Device Metrics

```promql
# Utilization - Disk I/O utilization
rate(node_disk_io_time_seconds_total[5m]) * 100

# Saturation - Disk I/O wait queue length
node_disk_io_time_weighted_seconds_total

# Errors - Disk errors
node_disk_errors_total
```

### Container Resource Metrics

```promql
# Utilization - Container CPU usage vs limit
sum(rate(container_cpu_usage_seconds_total[5m])) by (pod) / 
sum(kube_pod_container_resource_limits{resource="cpu"}) by (pod)

# Saturation - Container CPU throttling
sum(rate(container_cpu_cfs_throttled_periods_total[5m])) by (pod)

# Errors - Container restarts
kube_pod_container_status_restarts_total
```

## Alert Configuration

Example alert rules for the USE Method:

```yaml
# CPU Saturation Alert
- alert: HighCPUSaturation
  expr: node_load5 > count by (instance) (node_cpu_seconds_total{mode="idle"}) * 0.8
  for: 5m
  labels:
    severity: warning
    team: sre
  annotations:
    summary: "High CPU saturation"
    description: "CPU run queue is saturated on {{ $labels.instance }}"

# Memory Saturation Alert
- alert: HighMemorySaturation
  expr: node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes < 0.1
  for: 5m
  labels:
    severity: warning
    team: sre
  annotations:
    summary: "High memory saturation"
    description: "Less than 10% memory available on {{ $labels.instance }}"

# Network Error Alert
- alert: NetworkInterfaceErrors
  expr: rate(node_network_transmit_errs_total[5m]) + rate(node_network_receive_errs_total[5m]) > 0
  for: 5m
  labels:
    severity: warning
    team: sre
  annotations:
    summary: "Network interface errors detected"
    description: "Network errors detected on {{ $labels.instance }} interface {{ $labels.device }}"

# Disk Saturation Alert
- alert: HighDiskSaturation
  expr: rate(node_disk_io_time_weighted_seconds_total[5m]) > 1
  for: 5m
  labels:
    severity: warning
    team: sre
  annotations:
    summary: "High disk saturation"
    description: "Disk I/O is saturated on {{ $labels.instance }} device {{ $labels.device }}"
```

## Dashboard Guide

The USE Method dashboard is organized by resource types:

1. **CPU Resources**
   - CPU Utilization (by node)
   - CPU Saturation (load averages and run queue)
   - CPU Errors (throttles, if available)

2. **Memory Resources**
   - Memory Utilization (percentage used)
   - Memory Saturation (paging activity, OOM kills)
   - Memory Errors (if available)

3. **Network Resources**
   - Network Interface Utilization
   - Network Interface Saturation (drops)
   - Network Interface Errors

4. **Storage Resources**
   - Storage Device Utilization
   - Storage Device Saturation (wait queue)
   - Storage Device Errors

5. **Container Resources**
   - Container CPU/Memory Utilization
   - Container Resource Saturation
   - Container Errors

## Integration with RED Method

The USE Method complements the RED Method:

- **RED Method**: Focuses on the experience of your service's users
- **USE Method**: Focuses on the health of the resources that your service depends on

By implementing both, we get:
1. User-centric view (RED): How users are experiencing the service
2. Resource-centric view (USE): Why the service might be performing poorly

## Troubleshooting with the USE Method

1. **Identify Resources**: List all hardware and software resources
2. **Check Errors**: First look for error metrics (quickest to diagnose)
3. **Check Utilization**: Look for resources at or near 100% utilization
4. **Check Saturation**: Look for resources with queued work
5. **Drill Down**: For problem resources, use other methodologies to investigate further

## References

- [USE Method by Brendan Gregg](http://www.brendangregg.com/usemethod.html)
- [Systems Performance: Enterprise and the Cloud](https://www.brendangregg.com/systems-performance-2nd-edition-book.html)
- [Prometheus Node Exporter](https://github.com/prometheus/node_exporter)
- [Kubernetes Metrics](https://kubernetes.io/docs/concepts/cluster-administration/monitoring/)
