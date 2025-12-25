# Confluence Helpers for Claude Code Skills

Reusable patterns for Confluence page creation and management, specifically for incident post-mortems.

## Confluence Configuration

**Space**: `Tech`
**Parent Folder ID**: `287244316` (Post Mortems folder)
**Format**: Markdown (converted to Confluence storage format)

## Post-Mortem Creation Pattern

### Pattern: Create Post-Mortem Page

```markdown
Use `mcp__atlassian__createConfluencePage` tool:

Parameters:
- cloudId: {confluence_cloud_id or site URL}
- spaceId: "Tech" space ID (resolve from space key)
- parentId: "287244316" (Post Mortems folder)
- title: "Incident: {incident_name} - {date}"
- body: {post_mortem_content_markdown}
- contentFormat: "markdown"

Example title: "Incident: API Outage - 2025-12-19"
```

### Post-Mortem Template

**Location**: `.claude/shared/confluence/templates/post_mortem_template.md`

```markdown
# Incident: {{incident_name}}

**Date:** {{incident_date}}
**Severity:** {{severity}}
**Impact:** {{impact_description}}
**Status:** {{status}}

---

## Incident Metadata

| Field | Value |
|-------|-------|
| **Incident ID** | {{incident_id}} |
| **Severity** | {{severity}} |
| **Affected Regions** | {{regions}} |
| **Start Time** | {{start_time}} |
| **End Time** | {{end_time}} |
| **Total Duration** | {{total_duration}} |
| **Detection Method** | {{detection_method}} |
| **Root Cause** | {{root_cause_brief}} |

---

## Timescale by Region

{{#each regions}}
### {{region_name}}

| Metric | Value |
|--------|-------|
| **Start Time** | {{start_time}} ({{timezone}}) |
| **End Time** | {{end_time}} ({{timezone}}) |
| **Duration** | {{duration_minutes}} minutes |
| **SLA Duration** | {{sla_duration_minutes}} minutes (business hours only) |
| **Users Affected** | {{users_affected}} |

**SLA Calculation**: Business hours 9am-5pm, Monday-Friday {{timezone}}
{{/each}}

**Total Combined SLA Duration**: {{total_sla_minutes}} minutes

---

## Resolution

### Actions Taken

{{actions_taken}}

### Remediation Steps

1. {{remediation_step_1}}
2. {{remediation_step_2}}
3. {{remediation_step_3}}

---

## Incident Log

| Timestamp | Event | Actor |
|-----------|-------|-------|
{{#each incident_log}}
| {{timestamp}} | {{event_description}} | {{actor}} |
{{/each}}

---

## Root Cause Analysis

### Primary Cause

{{root_cause_analysis}}

### Contributing Factors

{{#each contributing_factors}}
- {{factor_description}}
{{/each}}

---

## Corrective and Preventive Actions

### Immediate Actions (Completed)

{{#each immediate_actions}}
- [x] {{action_description}} - {{completion_date}}
{{/each}}

### Short-term Actions (1-2 weeks)

{{#each short_term_actions}}
- [ ] {{action_description}} - **Owner**: {{owner}}
{{/each}}

### Long-term Actions (1-3 months)

{{#each long_term_actions}}
- [ ] {{action_description}} - **Owner**: {{owner}}
{{/each}}

---

## Lessons Learned

### What Went Well

{{what_went_well}}

### What Could Be Improved

{{what_could_improve}}

### Action Items

{{#each action_items}}
- {{action_description}} - **Owner**: {{owner}}, **Due**: {{due_date}}
{{/each}}

---

*Post-mortem created: {{creation_date}}*
*Created with Claude Code*
*Link to incident work item: [ADO #{{incident_id}}](https://dev.azure.com/{organization}/{project}/_workitems/edit/{{incident_id}})*
```

## SLA Calculation Patterns

### Pattern: Calculate Business Hours Duration

**Purpose**: Calculate SLA duration excluding weekends and non-business hours (9am-5pm).

**Algorithm**:

```markdown
calculate_sla_duration(start_time: datetime, end_time: datetime, timezone: str) -> int:
    """
    Calculate SLA duration in minutes, excluding weekends and non-business hours.

    Business hours: 9:00 AM - 5:00 PM (8 hours per day)
    Business days: Monday - Friday

    Args:
        start_time: Incident start time (ISO 8601)
        end_time: Incident end time (ISO 8601)
        timezone: Timezone for business hours (e.g., "America/New_York")

    Returns:
        SLA duration in minutes
    """

    1. Convert start_time and end_time to timezone
    2. Initialize sla_minutes = 0
    3. current_time = start_time

    4. While current_time < end_time:
        a. If current_time is weekend (Saturday/Sunday):
           - Skip to Monday 9am
           - Continue loop

        b. If current_time.hour < 9 (before business hours):
           - Set current_time to 9:00 AM same day
           - Continue loop

        c. If current_time.hour >= 17 (after business hours):
           - Skip to next business day 9:00 AM
           - Continue loop

        d. Otherwise (within business hours):
           - Calculate minutes until end of business day (5pm) or end_time
           - Add to sla_minutes
           - Move current_time forward

    5. Return sla_minutes
```

### Example Calculation

```markdown
Scenario:
- Start: Friday 2025-12-19 16:30 (4:30 PM)
- End: Monday 2025-12-22 10:15 (10:15 AM)
- Timezone: America/New_York

Calculation:
1. Friday 16:30-17:00: 30 minutes (end of business day)
2. Saturday/Sunday: 0 minutes (weekend, excluded)
3. Monday 09:00-10:15: 75 minutes (1 hour 15 minutes)

Total SLA Duration: 105 minutes (1 hour 45 minutes)
```

### Bash Implementation Reference

```bash
calculate_sla_duration() {
    local start_time="$1"  # ISO 8601 format
    local end_time="$2"    # ISO 8601 format
    local timezone="$3"    # e.g., "America/New_York"

    # Convert to Unix timestamps in timezone
    local start_ts=$(TZ="$timezone" date -d "$start_time" +%s)
    local end_ts=$(TZ="$timezone" date -d "$end_time" +%s)

    local sla_minutes=0
    local current_ts=$start_ts

    while [ $current_ts -lt $end_ts ]; do
        # Get day of week (1=Monday, 7=Sunday)
        local dow=$(TZ="$timezone" date -d "@$current_ts" +%u)

        # Skip weekends
        if [ $dow -eq 6 ] || [ $dow -eq 7 ]; then
            # Skip to Monday 9am
            local next_monday=$((current_ts + (8 - dow) * 86400))
            current_ts=$(TZ="$timezone" date -d "$(date -d "@$next_monday" +%Y-%m-%d) 09:00:00" +%s)
            continue
        fi

        # Get hour of day
        local hour=$(TZ="$timezone" date -d "@$current_ts" +%H)

        # Before business hours (9am)
        if [ $hour -lt 9 ]; then
            current_ts=$(TZ="$timezone" date -d "$(date -d "@$current_ts" +%Y-%m-%d) 09:00:00" +%s)
            continue
        fi

        # After business hours (5pm)
        if [ $hour -ge 17 ]; then
            # Skip to next business day 9am
            local next_day=$((current_ts + 86400))
            current_ts=$(TZ="$timezone" date -d "$(date -d "@$next_day" +%Y-%m-%d) 09:00:00" +%s)
            continue
        fi

        # Within business hours - calculate minutes
        local end_of_day=$(TZ="$timezone" date -d "$(date -d "@$current_ts" +%Y-%m-%d) 17:00:00" +%s)
        local segment_end=$([ $end_ts -lt $end_of_day ] && echo $end_ts || echo $end_of_day)

        local segment_minutes=$(( (segment_end - current_ts) / 60 ))
        sla_minutes=$((sla_minutes + segment_minutes))

        current_ts=$segment_end
    done

    echo $sla_minutes
}

# Usage
sla_minutes=$(calculate_sla_duration "2025-12-19T16:30:00-05:00" "2025-12-22T10:15:00-05:00" "America/New_York")
echo "SLA Duration: $sla_minutes minutes"
```

## Multi-Region SLA Calculation

### Pattern: Calculate Per-Region SLA

```markdown
For incidents affecting multiple regions:

1. For each region:
   a. Get region timezone
   b. Calculate SLA duration using regional business hours
   c. Store: {region_name, sla_minutes, timezone}

2. Calculate total SLA impact:
   - Sum all regional SLA minutes
   - Or use max SLA across regions (depending on policy)

3. Report in post-mortem:
   - Table showing SLA per region
   - Total combined SLA duration
   - Business hour definitions per timezone
```

### Example Multi-Region Calculation

```markdown
Incident: API Outage
- North America (Eastern): 105 minutes SLA
- Europe (CET): 120 minutes SLA
- Asia Pacific (JST): 0 minutes SLA (outside business hours)

Total Combined SLA Impact: 225 minutes
```

## Confluence Page Operations

### Pattern 1: Get Space ID from Space Key

```markdown
Use `mcp__atlassian__getConfluenceSpaces` tool:

Parameters:
- cloudId: {site_url or cloud_id}
- keys: ["Tech"]

Extract spaceId from results for use in page creation.
```

### Pattern 2: Create Page with Parent

```markdown
1. Resolve space ID from space key "Tech"
2. Use parent ID "287244316" (Post Mortems folder)
3. Create page with markdown content
4. After creation, get page ID from response
5. Update page to add self-referencing link (optional)
```

### Pattern 3: Update Page to Add Self-Link

```markdown
After creating page:

1. Get page ID from creation response
2. Construct page URL: https://{site}.atlassian.net/wiki/spaces/Tech/pages/{page_id}
3. Append to page content:
   "View this post-mortem: [Incident Link]({page_url})"
4. Update page with mcp__atlassian__updateConfluencePage
```

## Error Handling

### Page Creation Failed

```markdown
## ❌ Confluence Page Creation Failed

**Error**: {error_message}

Possible reasons:
- Invalid space ID or parent ID
- Insufficient permissions
- Network connectivity issues
- Confluence API temporary unavailable

**Troubleshooting:**
- Verify space key "Tech" exists
- Verify parent folder ID "287244316" is accessible
- Check Confluence authentication
- Test Confluence MCP server connection

The post-mortem content has been prepared but not published.
You can manually create the page in Confluence:
1. Navigate to Tech space > Post Mortems folder
2. Create new page
3. Copy content from prepared template
```

## Usage in Skills

Skills should reference Confluence patterns when creating post-mortems:

```markdown
# In SKILL.md (create-post-mortem)

## Confluence Integration

This Skill creates incident post-mortem pages in Confluence.

**Reference**: See `.claude/shared/confluence/README.md` for:
- Post-mortem template structure
- SLA calculation algorithm
- Multi-region patterns
- Page creation workflows

**MCP Tools Used**:
- mcp__atlassian__getConfluenceSpaces
- mcp__atlassian__createConfluencePage
- mcp__atlassian__updateConfluencePage
```

## Testing

When implementing Confluence post-mortems:

1. **Test page creation**: Create test post-mortem in Tech space
2. **Test SLA calculation**: Verify business hours logic with edge cases
3. **Test multi-region**: Calculate SLA for 2-3 different timezones
4. **Test weekend handling**: Incident spanning Friday-Monday
5. **Test template variables**: Verify all placeholders substituted
6. **Test markdown rendering**: Check formatting in Confluence

## Notes

- Business hours: 9am-5pm local time (8 hours/day)
- Business days: Monday-Friday only
- SLA excludes weekends and non-business hours
- Each region has its own timezone for business hour calculations
- Post-mortems are stored in Tech space > Post Mortems folder (ID: 287244316)
- Markdown is converted to Confluence storage format automatically
- Page titles should follow pattern: "Incident: {name} - {date}"
- Always include link back to Azure DevOps incident work item
