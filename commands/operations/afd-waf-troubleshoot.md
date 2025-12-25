# /afd-waf-troubleshoot

**Role:** Azure Front Door and Web Application Firewall Debugging Specialist

You are an expert in diagnosing and resolving Azure Front Door (AFD) routing issues and Web Application Firewall (WAF) blocks. This command delegates to the **azure-edge-specialist** agent for comprehensive edge networking and security analysis.

## Usage

```
/afd-waf-troubleshoot
```

**No arguments required** - The command will guide you through interactive troubleshooting.

## Overview

This command addresses two primary issue categories:
1. **AFD Routing Issues**: Wrong origin selected, 404 errors, redirect loops
2. **WAF Blocks**: Legitimate traffic blocked by firewall rules

## Workflow

### Step 1: Identify Issue Type

Ask the user to select the issue category:

```markdown
## What issue are you experiencing?

1. **WAF Blocking Legitimate Traffic** - Users getting 403 Forbidden errors
2. **AFD Routing Issues** - Wrong backend selected, 404 errors, redirect loops
3. **Edge Caching Issues** - Cache not working or stale content
4. **SSL/TLS Certificate Issues** - Certificate errors at edge
5. **General AFD Performance** - Slow response times, latency

Select issue type (1-5):
```

### Step 2: Delegate to Azure Edge Specialist Agent

Based on selection, invoke the **azure-edge-specialist** agent with specific focus area.

---

## Issue Type 1: WAF Blocking Legitimate Traffic

### Investigation Steps

**1. Check WAF Logs**
```kusto
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.CDN"
| where Category == "FrontdoorWebApplicationFirewallLog"
| where action_s == "Block"
| project TimeGenerated, requestUri_s, ruleName_s, ruleId_s, details_message_s, clientIP_s
| order by TimeGenerated desc
| take 100
```

**2. Identify Triggering Rules**
Common WAF rules that cause false positives:
- **942xxx**: SQL Injection (SQLi) rules
- **941xxx**: Cross-Site Scripting (XSS) rules
- **930xxx**: Local File Inclusion (LFI) rules
- **932xxx**: Remote Code Execution (RCE) rules
- **Custom Rate Limit**: High-volume legitimate clients

**3. Analyze Request Pattern**
- Which requests are being blocked?
- What parameters/headers trigger the rule?
- Is the traffic legitimate?

### Resolution Steps

#### Create WAF Rule Exclusions

```markdown
## Resolution: Add WAF Exclusions

**Identified Rule**: {rule_id} - {rule_name}
**Legitimate Traffic**: Yes
**Resolution**: Create exclusion for specific request fields

### Step 1: Identify Match Variable
Common match variables:
- **RequestBodyPostArgNames**: Form field names
- **RequestBodyPostArgValues**: Form field values
- **RequestCookieNames**: Cookie names
- **RequestHeaderNames**: Header names
- **QueryStringArgNames**: Query parameter names

### Step 2: Create Exclusion in Azure Portal

1. Navigate to Azure Portal → Front Door → WAF Policy
2. Select "Managed Rules"
3. Find the triggering rule group (e.g., "SQLI-942xxx")
4. Click "Add Exception"
5. Configure exclusion:
   ```json
   {
     "matchVariable": "RequestBodyPostArgNames",
     "selectorMatchOperator": "Equals",
     "selector": "description"  // The field name being flagged
   }
   ```
6. Save changes (propagation takes 1-2 minutes)

### Step 3: Test After Exclusion
```bash
# Retry the previously blocked request
curl -X POST https://{afd-endpoint}/api/test \
  -H "Content-Type: application/json" \
  -d '{"description": "test with SQL-like content"}'

# Should return 200, not 403
```

### Common Exclusion Patterns:

**SQLi False Positive (942xxx)**:
```json
{
  "matchVariable": "RequestBodyPostArgNames",
  "selectorMatchOperator": "Equals",
  "selector": "query"  // Field containing SQL-like text
}
```

**XSS False Positive (941xxx)**:
```json
{
  "matchVariable": "RequestBodyPostArgValues",
  "selectorMatchOperator": "Equals",
  "selector": "htmlContent"  // Field containing HTML
}
```

**Rate Limit False Positive**:
- Add IP to allowlist
- Increase rate limit threshold
- Use custom rate limit rule for specific clients
```

#### Switch Rule to Detection Mode

```markdown
## Alternative: Detection Mode Testing

**Purpose**: Log violations without blocking (for testing)

### Step 1: Change Rule Mode
1. Navigate to WAF Policy → Managed Rules
2. Select rule group (e.g., "SQLI-942xxx")
3. Change "Mode" from "Prevention" to "Detection"
4. Save

### Step 2: Monitor for 24-48 Hours
- Check WAF logs for "Log" actions (not "Block")
- Verify legitimate traffic is logged, not blocked
- Ensure no security issues from disabled rule

### Step 3: Apply Proper Exclusions
- After confirming legitimate traffic patterns
- Create specific exclusions
- Switch rule back to "Prevention" mode

**Warning**: Only use Detection mode temporarily for analysis
```

---

## Issue Type 2: AFD Routing Issues

### Investigation Steps

**1. Review Routing Configuration**
```bash
# Get Front Door routing rules
az afd route list --profile-name {profile} \
  --endpoint-name {endpoint} \
  --resource-group {rg}
```

**2. Check Route Priority**
- Higher priority routes are evaluated first
- Check for conflicting routes

**3. Test Route Matching**
```bash
# Test specific path
curl -v -H "Host: {custom-domain}" https://{afd-endpoint}/api/test

# Check X-Azure-Ref header for routing info
```

### Common Routing Problems

#### Problem: Wrong Origin Selected

**Symptom**: Request routed to incorrect backend

**Investigation**:
```markdown
1. Check route pattern matching
2. Verify origin group selection
3. Review routing rule conditions

**Example Issue**:
Route pattern: `/api/*`
Expected origin: backend-api
Actual origin: frontend-server

**Cause**: More specific route `/api/legacy/*` has lower priority
```

**Resolution**:
```markdown
1. Adjust route priority (higher = evaluated first)
2. Make route patterns more specific
3. Ensure origin group is correctly configured

**Fix Example**:
- Set `/api/legacy/*` to priority 1
- Set `/api/*` to priority 2
```

#### Problem: 404 Errors

**Symptom**: AFD returns 404 even though content exists

**Common Causes**:
1. **Path pattern doesn't match**:
   - Pattern: `/api/*`
   - Request: `/API/test` (case-sensitive!)
   - Resolution: Add case-insensitive match or multiple patterns

2. **Missing trailing slash handling**:
   - Pattern: `/api`
   - Request: `/api/` (with trailing slash)
   - Resolution: Add wildcard `/api{/*catch-all}`

3. **Origin path not transformed**:
   - Frontend pattern: `/api/*`
   - Backend expects: `/v1/api/*`
   - Resolution: Add path transform rule

**Resolution**:
```json
{
  "routes": {
    "api-route": {
      "patternsToMatch": ["/api/*", "/API/*"],  // Case variations
      "originGroup": "backend",
      "enabledState": "Enabled",
      "transforms": [
        {
          "name": "ModifyPath",
          "parameters": {
            "odatatype": "#Microsoft.Azure.Cdn.Models.DeliveryRuleUrlPathActionParameters",
            "sourcePattern": "/api/",
            "destination": "/v1/api/"  // Transform path for backend
          }
        }
      ]
    }
  }
}
```

#### Problem: Redirect Loops

**Symptom**: Too many redirects error in browser

**Common Causes**:
1. **HTTP-to-HTTPS redirect + origin redirect**:
   - AFD redirects HTTP → HTTPS
   - Origin redirects HTTPS → HTTP
   - Result: Infinite loop

2. **Conflicting redirect rules**:
   - Rule 1: Redirect `/old` → `/new`
   - Rule 2: Redirect `/new` → `/old`

3. **AFD and backend both redirecting**:
   - AFD rule set redirects
   - Backend also has redirect logic

**Resolution**:
```markdown
1. **Identify redirect source**:
   ```bash
   curl -I -L https://{afd-endpoint}/api/test
   # Check Location headers in redirect chain
   ```

2. **Fix redirect configuration**:
   - Remove duplicate redirects
   - Ensure AFD handles HTTPS redirect, not backend
   - Configure origin to accept HTTPS from AFD

3. **AFD Rule Set for HTTPS Redirect**:
   ```json
   {
     "ruleSet": {
       "rules": [
         {
           "name": "HttpsRedirect",
           "conditions": [
             {
               "typeName": "RequestSchemeCondition",
               "matchValues": ["HTTP"]
             }
           ],
           "actions": [
             {
               "typeName": "UrlRedirectAction",
               "redirectType": "PermanentRedirect",
               "destinationProtocol": "Https"
             }
           ]
         }
       ]
     }
   }
   ```
```

---

## Issue Type 3: Edge Caching Issues

### Investigation Steps

**1. Check Cache Status**
```kusto
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.CDN"
| where Category == "FrontdoorAccessLog"
| project TimeGenerated, requestUri_s, cacheStatus_s, httpStatusCode_d
| where cacheStatus_s in ("MISS", "HIT", "PARTIAL_HIT")
| summarize count() by cacheStatus_s
```

**2. Common Cache Statuses**:
- **HIT**: Served from cache (good!)
- **MISS**: Not in cache, fetched from origin
- **PARTIAL_HIT**: Range request, partial cache
- **NONE**: Caching disabled for this request

### Problem: Cache Not Working

**Investigation**:
```markdown
**Check Cache-Control Headers** (from origin):
```bash
curl -I https://{origin-backend}/api/test
# Look for: Cache-Control: no-cache, no-store, must-revalidate
```

**Common Causes**:
1. **Cache-Control headers prevent caching**
2. **Query strings bypass cache** (default behavior)
3. **Cookies invalidate cache**
4. **Dynamic content not cacheable**
```

**Resolution**:
```markdown
### Option 1: Override Cache-Control (AFD Rule Set)
```json
{
  "ruleSet": {
    "rules": [
      {
        "name": "CacheOverride",
        "actions": [
          {
            "typeName": "CacheExpirationAction",
            "cacheBehavior": "Override",
            "cacheDuration": "1.00:00:00"  // 1 day
          }
        ]
      }
    ]
  }
}
```

### Option 2: Ignore Query Strings
```json
{
  "routes": {
    "cached-route": {
      "queryStringCachingBehavior": "IgnoreQueryString"  // Cache regardless of query params
    }
  }
}
```

### Option 3: Configure Origin Cache-Control
Update backend to send proper headers:
```http
Cache-Control: public, max-age=3600
```

**Best Practices**:
- Static assets: Cache for long duration (days/weeks)
- API responses: Cache for short duration (minutes/hours)
- User-specific content: Don't cache or use private cache
```

### Problem: Stale Content

**Symptom**: Cache serving outdated content

**Resolution**:
```markdown
### Option 1: Purge Cache
```bash
# Purge single path
az afd endpoint purge --profile-name {profile} \
  --endpoint-name {endpoint} \
  --content-paths "/api/products/123" \
  --resource-group {rg}

# Purge wildcard
az afd endpoint purge --profile-name {profile} \
  --endpoint-name {endpoint} \
  --content-paths "/api/products/*" \
  --resource-group {rg}
```

### Option 2: Set Shorter Cache Duration
Reduce cache duration for frequently changing content:
```json
{
  "cacheBehavior": "Override",
  "cacheDuration": "00:05:00"  // 5 minutes instead of hours
}
```

### Option 3: Use Cache Tags (Advanced)
For granular purging based on tags instead of paths.
```

---

## Issue Type 4: SSL/TLS Certificate Issues

### Common Problems

**1. Certificate Expired**
**2. Certificate Mismatch** (domain not in SAN)
**3. Incomplete Certificate Chain**
**4. Custom Domain Not Working**

### Resolution Steps

See `/triage-504` command for detailed SSL/TLS troubleshooting steps.

Quick checks:
```bash
# Test SSL certificate
openssl s_client -connect {afd-endpoint}:443 -servername {custom-domain}

# Check certificate expiration
openssl s_client -connect {afd-endpoint}:443 -servername {custom-domain} 2>/dev/null | openssl x509 -noout -dates
```

---

## Validation Steps

After implementing any resolution:

```markdown
## Validation Checklist

### 1. Test Affected Endpoints
```bash
# Test via AFD
curl -v https://{afd-endpoint}/api/test

# Expected: HTTP 200 (or appropriate status)
# Check headers for routing/caching info
```

### 2. Check AFD Metrics (Azure Portal)
Navigate to Front Door → Metrics:
- Total requests (should continue)
- 4xx error rate (should decrease if fixing routing)
- 5xx error rate (should decrease if fixing origin issues)
- Cache hit ratio (should increase if fixing cache)

### 3. WAF Logs (if applicable)
```kusto
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.CDN"
| where Category == "FrontdoorWebApplicationFirewallLog"
| where timestamp > ago(15m)
| where action_s == "Block"
| summarize count() by ruleName_s
```

**Expected**: Count should drop for previously triggering rules

### 4. Monitor for 30 Minutes
- Watch for recurring issues
- Verify user reports improve
- Check error rates stabilize
```

## Error Handling

### If AFD Logs Unavailable
```
❌ Unable to Access AFD Diagnostics

**Troubleshooting**:
- Verify diagnostic settings configured for AFD
- Check Log Analytics workspace connection
- Allow 5 minutes for logs (delay is normal)
- Use AFD Metrics as alternative
```

### If WAF Rule Cannot Be Determined
```
❌ Unable to Identify Triggering WAF Rule

**Next Steps**:
1. Capture exact request that's being blocked
2. Check WAF logs with specific timestamp
3. Test request against WAF in Detection mode
4. Contact security team for WAF policy review
```

## Prevention & Best Practices

**WAF Management**:
- Start with Detection mode for new rules
- Create specific exclusions, not broad ones
- Document all exclusions with justification
- Review WAF logs monthly for false positives

**AFD Routing**:
- Use clear, specific route patterns
- Set appropriate route priorities
- Test routing changes in staging first
- Document routing logic for complex setups

**Caching**:
- Set appropriate cache durations per content type
- Use query string rules strategically
- Implement cache purge strategy
- Monitor cache hit ratio

**Monitoring**:
- Alert on 4xx spike (routing/WAF issues)
- Alert on 5xx spike (origin issues)
- Alert on cache hit ratio drop
- Review AFD logs weekly

## Integration

**Related Commands**:
- `/triage-504` - For 504 gateway timeout issues
- `/create-incident` - Document incident in Azure DevOps

**Related Agents**:
- **azure-edge-specialist** - Primary agent for this playbook
- **techops-triager** - For broader incident investigation

**Escalation**:
- Azure Support: For AFD platform issues
- Security team: For WAF policy decisions
- Network team: For complex routing scenarios

## Notes

- AFD configuration changes take 5-10 minutes to propagate globally
- WAF exclusions are immediately effective after save
- Cache purge affects all global PoPs within minutes
- AFD diagnostics logs have ~5 minute delay
- Premium AFD supports more advanced features (Private Link, custom WAF rules)
- Always test WAF exclusions in Detection mode first
- Document all WAF exclusions for security audit compliance
