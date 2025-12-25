# Update Coverage Command

You are tasked with running comprehensive test coverage analysis across the RaveHub codebase and updating the "Test Coverage Summary" section in `code-summary.md`.

## Instructions

### 1. Run Backend Coverage Analysis (Per Microservice)

Execute coverage for each backend microservice separately:

```bash
# Gateway Service
cd /home/corbinator/workspace/github/ravehub/ravehub-app
dotnet test backend/gateway/RaveHub.Gateway.Tests/RaveHub.Gateway.Tests.csproj \
  --collect:"XPlat Code Coverage" \
  --results-directory ./coverage-temp/gateway \
  --settings coverlet.runsettings \
  --verbosity quiet \
  --no-build || true

# Reference Service
dotnet test backend/reference/RaveHub.Reference.Tests/RaveHub.Reference.Tests.csproj \
  --collect:"XPlat Code Coverage" \
  --results-directory ./coverage-temp/reference \
  --settings coverlet.runsettings \
  --verbosity quiet \
  --no-build || true

# Events Service
dotnet test backend/events/RaveHub.Events.Tests/RaveHub.Events.Tests.csproj \
  --collect:"XPlat Code Coverage" \
  --results-directory ./coverage-temp/events \
  --settings coverlet.runsettings \
  --verbosity quiet \
  --no-build || true

# Identity Service
dotnet test backend/identity/RaveHub.Identity.Tests/RaveHub.Identity.Tests.csproj \
  --collect:"XPlat Code Coverage" \
  --results-directory ./coverage-temp/identity \
  --settings coverlet.runsettings \
  --verbosity quiet \
  --no-build || true
```

**Note**: Use `|| true` to continue even if a test project doesn't exist yet.

### 2. Parse Coverage Reports

For each microservice, locate the generated `coverage.cobertura.xml` file in `./coverage-temp/{service}/*/` and extract:
- **Line Coverage %**: `line-rate` attribute (multiply by 100)
- **Branch Coverage %**: `branch-rate` attribute (multiply by 100)

Example XML structure:
```xml
<coverage line-rate="0.8526" branch-rate="0.7921" ...>
```

### 3. Run Frontend Coverage (Optional)

If frontend tests are configured:

```bash
# ravehub-web (Next.js)
cd frontend/ravehub-web
npm test -- --coverage --silent --passWithNoTests 2>/dev/null || echo "No frontend tests configured"
cd ../..
```

Parse `frontend/ravehub-web/coverage/coverage-summary.json` if it exists.

### 4. Calculate Overall Coverage

**Formula**:
```
Overall Coverage = (Backend LOC * Backend Coverage + Frontend LOC * Frontend Coverage) / Total LOC

Where:
- Backend LOC: ~24,462 (from code-summary.md)
- Frontend LOC: ~24,250 (from code-summary.md)
```

### 5. Update code-summary.md

Locate the "## Test Coverage Summary" section (after "Code Quality Metrics") and update with:

```markdown
## Test Coverage Summary

**Last Updated**: {today's date}
**Overall Coverage**: {calculated}% / 80.0% target {status-emoji}

### Backend Coverage: {average-backend}% {status-emoji}

| Microservice | Line Coverage | Branch Coverage | Status |
|--------------|---------------|-----------------|--------|
| Gateway | {gateway-line}% | {gateway-branch}% | {emoji} |
| Reference | {reference-line}% | {reference-branch}% | {emoji} |
| Events | {events-line}% | {events-branch}% | {emoji} |
| Identity | {identity-line}% | {identity-branch}% | {emoji} |

### Frontend Coverage: {average-frontend}% {status-emoji}

| Application | Line Coverage | Branch Coverage | Status |
|-------------|---------------|-----------------|--------|
| ravehub-web | {web-line}% | {web-branch}% | {emoji} |
| ravehub-mobile | N/A | N/A | ⏸️ Not configured |

### Coverage Analysis

- **Backend Average**: {avg}% across {count} microservices
- **Target Status**: {on-track/needs-improvement}
- **Top Performer**: {service-name} ({coverage}%)
- **Needs Attention**: {service-name} ({coverage}%) - below 80% target

### Microservice Details

#### Gateway Service
- **Status**: {emoji} {status-text}
- **Coverage**: {line}% line, {branch}% branch
- **Test Files**: {count} test files found
- **Priority**: {High/Medium/Low}

#### Reference Service
- **Status**: {emoji} {status-text}
- **Coverage**: {line}% line, {branch}% branch
- **Test Files**: {count} test files found
- **Priority**: {High/Medium/Low}

#### Events Service
- **Status**: {emoji} {status-text}
- **Coverage**: {line}% line, {branch}% branch
- **Test Files**: {count} test files found
- **Notes**: Phase 2 target 82% - {met/not met}

#### Identity Service
- **Status**: {emoji} {status-text}
- **Coverage**: {line}% line, {branch}% branch
- **Test Files**: {count} test files found
- **Priority**: {High/Medium/Low}

### Recommendations

{Generate 2-3 actionable recommendations based on coverage gaps}
```

### 6. Status Emoji Logic

- ✅ Green: >= 80%
- ⚠️ Yellow: 60-79%
- ❌ Red: < 60%
- ⏸️ Gray: Not configured / No tests

### 7. Cleanup

```bash
# Remove temporary coverage files
rm -rf ./coverage-temp
```

### 8. Output Summary

Print a summary:
```
Coverage Analysis Complete!

Overall: {x}% / 80% target {emoji}
Backend: {x}% {emoji}
Frontend: {x}% {emoji}

Updated code-summary.md with latest coverage data.

Top Performers:
  1. {service}: {x}%
  2. {service}: {x}%

Needs Improvement:
  1. {service}: {x}% (below target)
```

## Error Handling

- If a test project doesn't exist, show "N/A" in the table
- If coverage report is not found, show "⏸️ No coverage data"
- If tests fail, still parse whatever coverage was generated
- Continue processing other services even if one fails

## Expected Behavior

- Should take 2-5 minutes to complete (running all tests)
- Provides comprehensive coverage breakdown
- Updates code-summary.md in place
- Cleans up temporary files
- Reports actionable insights

## Notes

- This command runs actual tests, so it's slower than `/update-code-summary`
- Use this before major milestones, PRs, or phase completions
- Backend should target 80%+ coverage
- Frontend coverage is aspirational (may be low initially)
- Events Service Phase 2 target: 82%+ (currently achieved)
