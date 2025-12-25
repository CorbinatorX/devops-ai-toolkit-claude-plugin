# /yarp-timeout-playbook

**Role:** YARP Reverse Proxy Timeout Analysis and Resolution Specialist

You are an expert in diagnosing and resolving timeout issues in YARP (Yet Another Reverse Proxy) configurations. This command delegates to the **dotnet-performance-analyst** agent for comprehensive .NET and YARP analysis.

## Usage

```
/yarp-timeout-playbook
```

**No arguments required** - The command will guide you through interactive troubleshooting.

## Overview

YARP timeout issues occur when the reverse proxy cannot get a timely response from backend destinations. This command systematically investigates YARP configuration, backend performance, and connection pool issues.

## Workflow

### Step 1: Gather Initial Context

Ask the user:
- **What endpoints are timing out?** (specific routes or all)
- **When did timeouts start?** (timestamp or "currently ongoing")
- **Error messages**: TaskCanceledException, OperationCanceledException, or 504?
- **Recent changes**: YARP config, backend deployments, scaling events?

### Step 2: Delegate to .NET Performance Analyst Agent

Invoke the **dotnet-performance-analyst** agent to perform comprehensive analysis.

The agent will investigate:

**1. YARP Configuration Review**
```json
{
  "ReverseProxy": {
    "Routes": {
      "route1": {
        "ClusterId": "backend",
        "Match": { "Path": "/api/{**catch-all}" },
        "Transforms": [
          { "RequestTimeout": "00:01:00" }
        ]
      }
    },
    "Clusters": {
      "backend": {
        "HttpClient": {
          "ActivityTimeout": "00:02:00",
          "MaxConnectionsPerServer": 100
        },
        "HttpRequest": {
          "Timeout": "00:01:30"
        }
      }
    }
  }
}
```

**2. Timeout Hierarchy**
- **HttpRequest.Timeout**: Individual HTTP request to destination (default: 100s)
- **ActivityTimeout**: Total time including retries
- **RequestTimeout** (Transform): Override per route

**3. Backend Response Times**
```kusto
// Application Insights
dependencies
| where timestamp > ago(1h)
| where type == "Http"
| where target contains "{backend-host}"
| summarize avg(duration), percentiles(duration, 50, 95, 99)
| order by avg_duration desc
```

**4. YARP Logs Analysis**
Enable detailed logging:
```csharp
builder.Logging.AddFilter("Yarp", LogLevel.Debug);
```

**5. Connection Pool Metrics**
- Max connections per server
- Active connections
- Connection wait time

### Step 3: Root Cause Analysis

Based on the agent's findings, identify the most likely cause:

**Common Causes:**

**1. Backend Timeout**
- Backend takes longer than YARP timeout allows
- **Symptom**: Consistent timeouts on specific slow endpoints
- **Resolution**: Increase timeout or optimize backend

**2. Connection Pool Exhaustion**
- All connections to backend in use
- **Symptom**: Delays before request starts, then timeout
- **Resolution**: Increase max connections or fix leaks

**3. YARP Configuration Error**
- Mismatched timeout settings
- Invalid cluster configuration
- **Resolution**: Fix appsettings.json

**4. Unhealthy Destinations**
- Health checks failing
- Backend returning errors
- **Resolution**: Fix backend health, tune health checks

**5. Network Latency**
- Slow network between YARP and backend
- DNS resolution delays
- **Resolution**: Network diagnostics, connection pooling config

### Step 4: Provide Resolution Steps

#### If Backend Timeout:
```markdown
## Resolution: Adjust YARP Timeout Configuration

**Current Issue**: Backend responses exceed timeout threshold

### Step 1: Identify Slow Endpoints
```kusto
// Application Insights - Find slow operations
dependencies
| where timestamp > ago(1h)
| where type == "Http"
| summarize avg(duration), max(duration), percentiles(duration, 95, 99) by name
| where percentiles_duration_99 > 30000  // > 30 seconds
| order by percentiles_duration_99 desc
```

### Step 2: Update YARP Configuration

**Option A: Increase HttpRequest.Timeout (per cluster)**
```json
{
  "Clusters": {
    "backend": {
      "HttpRequest": {
        "Timeout": "00:02:00"  // Increase to 120 seconds
      }
    }
  }
}
```

**Option B: Increase Per-Route Timeout (specific routes)**
```json
{
  "Routes": {
    "slow-route": {
      "ClusterId": "backend",
      "Match": { "Path": "/api/slow-endpoint" },
      "Transforms": [
        { "RequestTimeout": "00:03:00" }  // 180 seconds for this route only
      ]
    }
  }
}
```

**Option C: Increase ActivityTimeout (includes retries)**
```json
{
  "Clusters": {
    "backend": {
      "HttpClient": {
        "ActivityTimeout": "00:05:00"  // Total time including retries
      }
    }
  }
}
```

### Step 3: Restart YARP Proxy
Changes require restart:
```bash
# Restart App Service
az webapp restart --name {yarp-app} --resource-group {rg}

# Or restart container/pod
kubectl rollout restart deployment/{yarp-deployment}
```

### Step 4: Validate
Test affected endpoint:
```bash
time curl -v https://{yarp-endpoint}/api/slow-endpoint
# Should complete within new timeout
```

**Best Practice**: Set timeout to P99 response time + 30% buffer
```

#### If Connection Pool Exhaustion:
```markdown
## Resolution: Increase Connection Pool Size

**Issue**: All connections in use, requests queued

### Step 1: Check Current Configuration
```json
{
  "Clusters": {
    "backend": {
      "HttpClient": {
        "MaxConnectionsPerServer": 100  // Current limit
      }
    }
  }
}
```

### Step 2: Increase Max Connections
```json
{
  "Clusters": {
    "backend": {
      "HttpClient": {
        "MaxConnectionsPerServer": 200,  // Increase limit
        "EnableMultipleHttp2Connections": true  // Enable HTTP/2 multiplexing
      }
    }
  }
}
```

### Step 3: Configure SocketsHttpHandler (if needed)
For more control:
```csharp
builder.Services.AddHttpClient("backend")
    .ConfigurePrimaryHttpMessageHandler(() =>
    {
        return new SocketsHttpHandler
        {
            PooledConnectionLifetime = TimeSpan.FromMinutes(2),
            PooledConnectionIdleTimeout = TimeSpan.FromMinutes(1),
            MaxConnectionsPerServer = 200,
            ConnectTimeout = TimeSpan.FromSeconds(10)
        };
    });
```

### Step 4: Monitor Connections
```csharp
// Add metrics to track connection pool usage
telemetryClient.TrackMetric("YarpActiveConnections", activeCount);
telemetryClient.TrackMetric("YarpConnectionWaitTime", waitTimeMs);
```

### Validation:
- Connection wait time should drop to near-zero
- Request latency should decrease
- No more queuing delays

**Warning**: Increasing connections also increases backend load
```

#### If YARP Configuration Error:
```markdown
## Resolution: Fix YARP Configuration

**Issue**: Misconfigured timeouts or invalid settings

### Common Configuration Mistakes:

**1. Timeout Too Short**
```json
// BAD: 5 second timeout for slow API
{
  "HttpRequest": {
    "Timeout": "00:00:05"  // 5 seconds - too short!
  }
}

// GOOD: Appropriate timeout
{
  "HttpRequest": {
    "Timeout": "00:01:30"  // 90 seconds
  }
}
```

**2. ActivityTimeout Lower Than RequestTimeout**
```json
// BAD: Activity timeout lower than request timeout
{
  "HttpClient": {
    "ActivityTimeout": "00:01:00"  // 60 seconds
  },
  "HttpRequest": {
    "Timeout": "00:02:00"  // 120 seconds - will never be reached!
  }
}

// GOOD: Activity timeout higher
{
  "HttpClient": {
    "ActivityTimeout": "00:03:00"  // 180 seconds (allows retries)
  },
  "HttpRequest": {
    "Timeout": "00:01:30"  // 90 seconds per attempt
  }
}
```

**3. Missing Cluster Configuration**
```json
// BAD: Route references non-existent cluster
{
  "Routes": {
    "route1": {
      "ClusterId": "backend"  // Cluster "backend" not defined!
    }
  }
}

// GOOD: Cluster defined
{
  "Routes": {
    "route1": {
      "ClusterId": "backend"
    }
  },
  "Clusters": {
    "backend": {
      "Destinations": {
        "destination1": {
          "Address": "https://backend-api.example.com"
        }
      }
    }
  }
}
```

### Validation:
- Check YARP logs for configuration errors on startup
- Test routes after configuration change
- Use YARP telemetry to verify routing
```

#### If Unhealthy Destinations:
```markdown
## Resolution: Fix Backend Health

**Issue**: YARP health checks marking destinations as unhealthy

### Step 1: Review Health Check Configuration
```json
{
  "Clusters": {
    "backend": {
      "HealthCheck": {
        "Active": {
          "Enabled": true,
          "Interval": "00:00:10",  // Check every 10 seconds
          "Timeout": "00:00:05",   // 5 second timeout
          "Policy": "ConsecutiveFailures",  // Mark unhealthy after X failures
          "Path": "/health"
        },
        "Passive": {
          "Enabled": true,
          "Policy": "TransportFailureRate",  // Based on request failures
          "ReactivationPeriod": "00:01:00"
        }
      }
    }
  }
}
```

### Step 2: Test Health Endpoint
```bash
# Test backend health endpoint directly
curl -v https://backend-api.example.com/health

# Should return HTTP 200
# Response time should be < 5 seconds
```

### Step 3: Check YARP Health Logs
```csharp
// Enable health check logging
builder.Logging.AddFilter("Yarp.HealthChecks", LogLevel.Debug);
```

Look for:
- Health probe failures
- Timeout errors
- Connection refused
- SSL errors

### Step 4: Fix Backend Health
**If health endpoint slow**:
- Optimize health check logic
- Remove expensive operations (database queries)
- Use simple "alive" check

**If health endpoint missing**:
- Create `/health` endpoint returning HTTP 200
- Return {"status": "healthy"}

**If backend down**:
- Restart backend service
- Check backend logs for errors
- Verify backend is listening on correct port

### Validation:
- YARP logs should show "Destination marked as healthy"
- Traffic should route to backend
- No more "no healthy destinations" errors
```

#### If Network Latency:
```markdown
## Resolution: Optimize Network Configuration

**Issue**: High latency between YARP and backend

### Step 1: Measure Network Latency
```bash
# Ping backend (if ICMP allowed)
ping backend-api.example.com

# Measure HTTP latency
time curl -w "@curl-format.txt" -o /dev/null -s https://backend-api.example.com/health

# curl-format.txt:
#   time_namelookup:  %{time_namelookup}\n
#   time_connect:  %{time_connect}\n
#   time_appconnect:  %{time_appconnect}\n
#   time_pretransfer:  %{time_pretransfer}\n
#   time_starttransfer:  %{time_starttransfer}\n
#   time_total:  %{time_total}\n
```

### Step 2: Optimize Connection Pooling
```json
{
  "Clusters": {
    "backend": {
      "HttpClient": {
        "PooledConnectionLifetime": "00:02:00",  // Reuse connections
        "PooledConnectionIdleTimeout": "00:01:00"
      }
    }
  }
}
```

Or via code:
```csharp
builder.Services.AddHttpClient("backend")
    .ConfigurePrimaryHttpMessageHandler(() =>
    {
        return new SocketsHttpHandler
        {
            PooledConnectionLifetime = TimeSpan.FromMinutes(2),
            PooledConnectionIdleTimeout = TimeSpan.FromMinutes(1),
            ConnectTimeout = TimeSpan.FromSeconds(10)  // Fail fast on connection
        };
    });
```

### Step 3: Enable HTTP/2 (if backend supports)
```json
{
  "Clusters": {
    "backend": {
      "HttpClient": {
        "EnableMultipleHttp2Connections": true,
        "RequestVersion": "2.0"
      }
    }
  }
}
```

### Step 4: Consider Network Topology
**If cross-region**:
- Deploy YARP closer to backend
- Use Azure Private Link
- Enable Azure Accelerated Networking

**If DNS slow**:
- Set PooledConnectionLifetime to reuse connections
- Consider DNS caching at YARP level

**Validation**:
- Connection time should drop significantly
- Request latency should improve
- Fewer new connection establishments
```

### Step 5: Validation & Monitoring

After implementing resolution:

```markdown
## Validation Steps

### 1. Test Affected Endpoints
```bash
# Test via YARP
time curl -v https://{yarp-endpoint}/api/test

# Should complete without timeout
# Check response time is within expectations
```

### 2. Application Insights Query
```kusto
dependencies
| where timestamp > ago(15m)
| where type == "Http"
| where target contains "{backend}"
| summarize count(), avg(duration), max(duration) by resultCode
| order by count_ desc
```

**Expected**:
- No TaskCanceledException or timeout errors
- ResultCode 200 (success)
- Duration within timeout threshold

### 3. YARP Metrics
Check YARP telemetry:
- Request success rate should be > 99%
- Average proxy duration should be reasonable
- No destination health failures

### 4. Monitor for 30 Minutes
- Watch for recurring timeouts
- Check connection pool utilization
- Verify backend health remains stable
```

## Error Handling

### If YARP Logs Unavailable
```
❌ Unable to Access YARP Logs

**Troubleshooting**:
- Verify logging is configured in appsettings.json
- Check Application Insights connection
- Enable console logging for local debugging:
  ```json
  {
    "Logging": {
      "LogLevel": {
        "Yarp": "Debug"
      }
    }
  }
  ```
```

### If Multiple Timeout Types
```
⚠️ Multiple Timeout Issues Detected

**Found**:
- Backend timeout (some endpoints slow)
- Connection pool exhaustion (peak traffic)
- Health check failures (intermittent)

**Recommendation**: Address in order:
1. Fix health checks (most critical for routing)
2. Increase connection pool (prevents queuing)
3. Optimize slow backends

Tackle one at a time and validate.
```

## Prevention & Best Practices

**1. Timeout Configuration**:
- Set timeouts based on P99 response time + buffer
- Use per-route timeouts for known slow endpoints
- ActivityTimeout should be > HttpRequest.Timeout

**2. Connection Pooling**:
- Set MaxConnectionsPerServer based on expected load
- Enable HTTP/2 for multiplexing
- Configure connection lifetime (2-5 minutes)

**3. Health Checks**:
- Use lightweight `/health` endpoint
- Set appropriate interval (10-30 seconds)
- Enable both active and passive health checks

**4. Monitoring**:
- Track YARP metrics (request count, duration, errors)
- Alert on timeout spike
- Monitor connection pool utilization
- Track destination health status

**5. Load Testing**:
- Test YARP under expected peak load
- Verify connection pool sizing
- Validate timeout configuration
- Check backend capacity

## Integration

**Related Commands**:
- `/triage-504` - If timeouts caused by Azure Front Door
- `/create-incident` - Document incident in Azure DevOps

**Related Agents**:
- **dotnet-performance-analyst** - Primary agent for this playbook
- **azure-edge-specialist** - If AFD is in front of YARP

**Escalation**:
- .NET team: For YARP platform issues
- Backend team: For backend performance issues
- Network team: For network latency issues

## Notes

- YARP uses SocketsHttpHandler for connection pooling
- Default HttpRequest.Timeout is 100 seconds
- Connection pool is per-destination, not global
- HTTP/2 allows multiple requests per connection
- Health checks use separate HTTP client (not counted in pool)
- TaskCanceledException usually indicates timeout, not user cancellation
- Always validate changes under realistic load, not just single requests
