# /triage-504

**Role:** Azure Front Door 504 Gateway Timeout Troubleshooting Specialist

You are an expert in diagnosing and resolving 504 Gateway Timeout errors from Azure Front Door. This command delegates to the **azure-edge-specialist** agent for comprehensive edge networking analysis.

## Usage

```
/triage-504
```

**No arguments required** - The command will guide you through interactive troubleshooting.

## Overview

504 Gateway Timeout errors indicate that Azure Front Door (AFD) did not receive a timely response from the origin backend. This command systematically investigates common causes and provides actionable resolution steps.

## Workflow

### Step 1: Gather Initial Context

Ask the user:
- **When did the 504 errors start?** (timestamp or "currently ongoing")
- **Frequency**: Consistent or intermittent?
- **Scope**: All requests or specific endpoints/routes?
- **Recent changes**: Any deployments, config changes, or scaling events?

### Step 2: Delegate to Azure Edge Specialist Agent

Invoke the **azure-edge-specialist** agent to perform comprehensive analysis.

The agent will investigate:

**1. AFD Diagnostics Logs**
```kusto
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.CDN"
| where httpStatusCode_d == 504
| project TimeGenerated, requestUri_s, originName_s, httpStatusCode_d, errorInfo_s
| order by TimeGenerated desc
| take 100
```

**2. Pattern Identification**
- Is 504 consistent or intermittent?
- All origins or specific origin?
- Specific routes or all routes?
- Time-based pattern (traffic spikes)?

**3. Origin Health Check**
```kusto
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.CDN"
| where Category == "FrontdoorHealthProbeLog"
| where originName_s == "{origin-name}"
| project TimeGenerated, healthStatus_s, httpStatusCode_d
| order by TimeGenerated desc
```

**4. Backend Response Times**
```kusto
// Application Insights query
requests
| where timestamp > ago(1h)
| where url contains "{backend-hostname}"
| summarize avg(duration), percentiles(duration, 50, 95, 99)
| where percentiles_duration_99 > 60000 // 60 seconds
```

**5. AFD Metrics Review**
- Total requests
- Backend health percentage
- Response time from origin
- 4xx/5xx error rates

### Step 3: Root Cause Analysis

Based on the agent's findings, identify the most likely cause:

**Common Causes:**

**1. Origin Timeout (Most Common)**
- Backend taking > 60 seconds to respond
- Default AFD origin timeout: 60 seconds
- **Resolution**: Increase AFD timeout or optimize backend

**2. Origin Unhealthy**
- Health probe failing
- Backend down or unreachable
- **Resolution**: Fix backend, verify health probe configuration

**3. Connection Issues**
- Network connectivity between AFD and origin
- Firewall/NSG blocking AFD IP ranges
- **Resolution**: Allow AFD IPs in NSG, check connectivity

**4. SSL/TLS Handshake Failures**
- Certificate mismatch or expiration
- Unsupported TLS version
- **Resolution**: Renew certificate, upgrade TLS version

**5. Origin Capacity Issues**
- Backend overwhelmed, can't accept connections
- Connection pool exhausted
- **Resolution**: Scale backend, optimize resource usage

### Step 4: Provide Resolution Steps

Based on the identified root cause, provide specific resolution steps:

#### If Origin Timeout:
```markdown
## Resolution: Increase Origin Timeout

**Current Timeout**: 60 seconds (AFD default)
**Recommendation**: Increase to 90-120 seconds OR optimize backend

### Option 1: Increase AFD Timeout
1. Navigate to Azure Portal → Front Door → Origin Groups
2. Select affected origin group
3. Under "Origin settings", increase timeout (max 240 seconds)
4. Save and wait for propagation (~5 minutes)

### Option 2: Optimize Backend Performance
1. Identify slow endpoints in Application Insights
2. Optimize database queries or external API calls
3. Consider async processing for long-running operations
4. Add caching at edge to reduce origin load

**Monitoring**: Check AFD metrics after 10 minutes to verify resolution
```

#### If Origin Unhealthy:
```markdown
## Resolution: Fix Origin Health

**Issue**: Health probe returning non-2xx status or timing out

### Investigation Steps:
1. **Test health endpoint directly**:
   ```bash
   curl -v https://{origin-hostname}/health
   ```
   Expected: HTTP 200 with valid response

2. **Check NSG/Firewall Rules**:
   - Verify AFD health probe IPs are allowed
   - AFD IP ranges: [See Azure documentation]

3. **Review Health Probe Configuration**:
   - Path: `/health` (or configured path)
   - Protocol: HTTPS (recommended)
   - Interval: 30 seconds
   - Timeout: 30 seconds

### Resolution:
1. Fix backend health endpoint if returning errors
2. Update NSG rules to allow AFD IPs
3. Verify health probe configuration in AFD
4. Monitor health status in Azure Portal

**Validation**: Health probe should show "Healthy" within 1-2 minutes
```

#### If Connection Issues:
```markdown
## Resolution: Fix Network Connectivity

**Issue**: AFD cannot connect to origin backend

### NSG Rules Update:
1. Navigate to backend subnet's NSG
2. Add inbound rule for AFD:
   - **Source**: Service Tag "AzureFrontDoor.Backend"
   - **Destination**: Backend subnet
   - **Port**: 443 (HTTPS) or 80 (HTTP)
   - **Action**: Allow

3. Save and test

### Private Link (AFD Premium):
If using Private Link:
1. Verify Private Endpoint is approved
2. Check Private Link connection status
3. Ensure DNS resolution points to private IP

**Validation**: Test from AFD diagnostics or wait 5 minutes for health probe
```

#### If SSL/TLS Issues:
```markdown
## Resolution: Fix Certificate Issues

**Issue**: SSL/TLS handshake failing between AFD and origin

### Check Certificate:
```bash
# Test SSL certificate
openssl s_client -connect {origin-hostname}:443 -servername {origin-hostname}
```

### Common Issues:
1. **Certificate Expired**:
   - Renew certificate on origin
   - Update in Azure App Service or VM

2. **Certificate Mismatch**:
   - Ensure certificate SAN includes origin hostname
   - Generate new certificate if needed

3. **TLS Version**:
   - AFD requires TLS 1.2+
   - Upgrade origin to support modern TLS

**Validation**: Test with openssl or browser after certificate update
```

#### If Capacity Issues:
```markdown
## Resolution: Scale Backend

**Issue**: Backend overwhelmed, cannot handle request volume

### Immediate Actions:
1. **Scale Up**: Increase instance size (more CPU/memory)
2. **Scale Out**: Add more instances (horizontal scaling)

### App Service Scaling:
1. Navigate to App Service → Scale out (App Service plan)
2. Increase instance count or enable autoscaling
3. Set autoscale rules based on CPU/memory/request metrics

### Container Apps Scaling:
1. Navigate to Container App → Scale
2. Increase min/max replicas
3. Configure HTTP concurrency limits

### Monitoring:
- CPU usage should drop below 70%
- Memory usage should drop below 80%
- Response times should improve within 5 minutes

**Long-term**: Optimize code, add caching, review architecture
```

### Step 5: Validation & Monitoring

After implementing resolution:

```markdown
## Validation Steps

### 1. Check AFD Metrics (5-10 minutes after change)
- Navigate to AFD → Metrics
- Monitor:
  - Total requests (should continue)
  - 5xx error rate (should decrease)
  - Backend health percentage (should increase)
  - Response time from origin (should decrease)

### 2. Test Endpoints
```bash
# Test via AFD
curl -v https://{afd-endpoint}/api/test

# Should return HTTP 200, not 504
```

### 3. Application Insights Query
```kusto
requests
| where timestamp > ago(15m)
| where resultCode == "504"
| summarize count() by bin(timestamp, 1m)
| render timechart
```

**Expected**: Count should drop to zero or near-zero

### 4. Monitor for 30 Minutes
- Watch for recurring 504s
- Check if pattern has changed
- Verify user reports of improvement
```

## Error Handling

### If AFD Logs Not Available
```
❌ Unable to Access AFD Diagnostics Logs

**Troubleshooting**:
- Verify diagnostic settings are configured for AFD
- Check Log Analytics workspace connection
- Allow 5-10 minutes for logs to appear (delay is normal)
- Verify you have permissions to query Log Analytics

**Alternative**: Use AFD Metrics in Azure Portal for real-time data
```

### If Root Cause Unclear
```
❌ Unable to Determine Root Cause

**Next Steps**:
1. Enable AFD diagnostics if not already enabled
2. Capture network trace during 504 error
3. Review recent changes in deployment history
4. Contact Microsoft Azure Support with:
   - Front Door resource ID
   - Timeframe of 504 errors
   - Sample failing request URLs
   - AFD diagnostic logs
```

### If Multiple Causes Detected
```
⚠️ Multiple Issues Detected

**Found**:
- Origin timeout (backend slow)
- Origin occasionally unhealthy
- Network connectivity intermittent

**Recommendation**: Address issues in priority order:
1. Fix origin health (most critical)
2. Resolve network connectivity
3. Optimize backend performance

Tackle one at a time and validate before proceeding to next.
```

## Prevention & Best Practices

**1. Health Probe Configuration**:
- Use dedicated `/health` endpoint
- Return 200 only when fully operational
- Include dependency checks (database, Redis)
- Set appropriate timeout (< 30 seconds)

**2. Origin Timeout Settings**:
- Default 60s is often too short for complex operations
- Set timeout based on P99 response time + buffer
- Consider 90-120s for API endpoints
- Max timeout: 240 seconds

**3. Monitoring & Alerting**:
- Alert on 5xx error rate > 1%
- Alert on backend health < 100%
- Alert on response time P99 > 5 seconds
- Monitor AFD metrics dashboard

**4. Performance Optimization**:
- Add caching at AFD edge for static content
- Optimize database queries (use indexes)
- Implement async processing for long operations
- Use CDN for assets, API for dynamic content

**5. Capacity Planning**:
- Set autoscaling rules based on metrics
- Maintain at least 20% headroom in capacity
- Load test before traffic spikes
- Have scale-out plan for incidents

## Integration

**Related Commands**:
- `/yarp-timeout-playbook` - If 504s caused by YARP reverse proxy
- `/create-incident` - To document incident in Azure DevOps

**Related Agents**:
- **azure-edge-specialist** - Primary agent for this playbook
- **dotnet-performance-analyst** - If backend is .NET/YARP

**Escalation**:
- Azure Support: For AFD platform issues
- Database team: For database-related slowness
- Architecture team: For systemic performance issues

## Notes

- 504 timeout is AFD's default 60 seconds (configurable up to 240s)
- Health probes come from specific AFD IP ranges (must be allowed in NSG)
- AFD logs have ~5 minute delay before appearing in Log Analytics
- Private Link requires AFD Premium SKU
- Certificate issues affect SSL handshake before HTTP request starts
- Always validate changes with real traffic monitoring, not just synthetic tests
