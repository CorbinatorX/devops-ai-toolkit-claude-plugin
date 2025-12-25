---
name: review-task
description: Validate completed work using deterministic automated checks with 6-category scoring and letter grades (S/A/B/C/D/F)
allowed-tools: Read, Write, Bash, Grep, Glob
auto-discover:
  - "review task"
  - "validate task"
  - "check task"
  - "quality check"
  - "review phase"
---

# Review Task Skill

## Purpose

Objective quality assurance that validates completed work against defined acceptance criteria using deterministic, automated checks. Provides scored feedback with letter grades and actionable improvement suggestions.

This Skill delegates to the **manager** agent for comprehensive quality validation.

## Auto-Discovery Triggers

This Skill automatically activates when users mention:
- "Review task {service}/phase{N}#{task}"
- "Validate task {number}"
- "Check task quality {number}"
- "Quality check for {task}"

## Example Invocations

```
"Review task payment-service/phase1#2.1"
"Validate task 3.5"
"Check quality of phase2#4.2"
"Review the completed implementation"
```

## Task Reference Formats

**Full path**: `payment-service/phase1#3.1`
**Short format**: `3.1` - If context is clear
**With description**: `payment-service/phase1#3.1 Payment Service Implementation`

## Workflow

### 1. Parse Task Reference

Extract service/feature name, phase number, and task number.

### 2. Read Phase File

**Location**: `.claude/tasks/{service-or-feature-name}/{phase}.md`

Find task section by searching for `#### {task-number}`.

### 3. Extract Task Details

**Checkbox Tasks**: Lines starting with `- [ ]` or `- [x]`
**Acceptance Criteria**: Section starting with `**Acceptance Criteria:**`
**Location**: File paths in `**Location:**` annotations
**Commands**: Build/test commands from task or config

### 4. Delegate to Manager Agent

Invoke the **manager** agent to run automated checks and validation. The agent will:

#### A. Build Verification

Read build command from:
1. Task's **Commands:** section
2. `.claude/config.json` under `testing.commands.build`
3. Default based on tech stack

**Tech stack defaults:**
- **.NET**: `dotnet build`
- **Node.js**: `npm run build` or `npm run type-check`
- **Python**: `python -m py_compile` or `mypy .`
- **Go**: `go build ./...`
- **Java**: `mvn compile` or `gradle build`

#### B. Test Execution

Run test command and capture:
- Number of tests passed/failed
- Coverage percentage
- Specific test failures

#### C. Type Checking

For TypeScript, Python with type hints:
```bash
# TypeScript
tsc --noEmit

# Python
mypy src/
```

#### D. Linting (Optional)

```bash
# JavaScript/TypeScript
npm run lint

# Python
flake8 src/

# .NET
dotnet format --verify-no-changes
```

#### E. Security Scanning (Optional)

```bash
# Node.js
npm audit

# Python
safety check
```

### 5. Validate Acceptance Criteria

For each criterion:
- ✅ **Passed** - Automated checks confirm it
- ⚠️ **Failed** - Checks indicate issues
- ⏸️ **Manual** - Requires human judgment

### 6. Generate Scored Review Report

**IMPORTANT**: Always write to: `.claude/tasks/{service-or-feature}/{phase}_status.md`

## Scoring System

**6 Categories (0-20 points each, 100 total):**

### 1. Completeness (0-20 points)
- All checkbox items completed
- All acceptance criteria met
- No missing functionality
- Edge cases handled

**Scoring:**
- 20: All checkboxes ✅, all criteria met
- 15-19: 1-2 minor items incomplete
- 10-14: 3-4 items incomplete
- 5-9: Major functionality missing
- 0-4: Mostly incomplete

### 2. Code Quality (0-20 points)
- Clean, readable code
- Proper error handling
- No code smells
- Follows conventions

**Scoring:**
- 20: Exemplary code quality
- 15-19: Minor style issues
- 10-14: Several code smells
- 5-9: Significant quality issues
- 0-4: Poor code quality

### 3. Architecture (0-20 points)
- Follows blueprint design
- Proper layer separation
- Correct patterns used
- Good abstractions

**Scoring:**
- 20: Perfect adherence to blueprint
- 15-19: Minor deviations
- 10-14: Some architectural issues
- 5-9: Significant deviations
- 0-4: Ignores blueprint

### 4. Security (0-20 points)
- Input validation present
- No security vulnerabilities
- Authentication/authorization correct
- No secrets in code

**Scoring:**
- 20: Comprehensive security
- 15-19: Minor security gaps
- 10-14: Some vulnerabilities
- 5-9: Significant security issues
- 0-4: Critical security flaws

### 5. Testing (0-20 points)
- Tests exist and pass
- Coverage meets target (default 80%)
- Edge cases tested
- Integration tests present

**Scoring:**
- 20: ≥90% coverage, comprehensive tests
- 15-19: 80-89% coverage, good tests
- 10-14: 60-79% coverage, basic tests
- 5-9: 40-59% coverage, minimal tests
- 0-4: <40% coverage or no tests

### 6. Documentation (0-20 points)
- Code comments where needed
- README/docs updated
- API documentation present
- Complex logic explained

**Scoring:**
- 20: Excellent documentation
- 15-19: Good documentation
- 10-14: Adequate documentation
- 5-9: Minimal documentation
- 0-4: No documentation

## Letter Grades

**Total Score → Letter Grade:**
- **S (Superior)**: 95-100 points - Exceptional work
- **A (Excellent)**: 85-94 points - Exceeds expectations
- **B (Good)**: 75-84 points - Meets all requirements
- **C (Satisfactory)**: 65-74 points - Acceptable with issues
- **D (Needs Work)**: 55-64 points - Significant rework needed
- **F (Failing)**: 0-54 points - Does not meet requirements

## Status File Structure

The manager generates a comprehensive status file:

```markdown
# Phase {N} Implementation Status Report
## {Feature Name} - {Phase Title}

**Review Date:** {YYYY-MM-DD}
**Phase Status:** {✅ IMPLEMENTATION COMPLETE | ⚠️ NEEDS REWORK | ⏸️ IN PROGRESS}
**Overall Score:** {score}/100
**Letter Grade:** {S | A | B | C | D | F}
**Reviewer:** Manager (Automated Quality Assurance)

---

## Scoring Breakdown

| Category | Score | Grade | Status |
|----------|-------|-------|--------|
| Completeness | {X}/20 | {letter} | {✅/⚠️/⏸️} |
| Code Quality | {X}/20 | {letter} | {✅/⚠️/⏸️} |
| Architecture | {X}/20 | {letter} | {✅/⚠️/⏸️} |
| Security | {X}/20 | {letter} | {✅/⚠️/⏸️} |
| Testing | {X}/20 | {letter} | {✅/⚠️/⏸️} |
| Documentation | {X}/20 | {letter} | {✅/⚠️/⏸️} |
| **TOTAL** | **{X}/100** | **{letter}** | **{status}** |

---

## Detailed Assessment

### 1. Completeness ({X}/20) - {Grade}
{checkbox completion, acceptance criteria status, issues}

### 2. Code Quality ({X}/20) - {Grade}
{strengths, issues, linting results}

### 3. Architecture ({X}/20) - {Grade}
{blueprint adherence, structural issues}

### 4. Security ({X}/20) - {Grade}
{security checks, vulnerabilities}

### 5. Testing ({X}/20) - {Grade}
{test results, coverage analysis}

### 6. Documentation ({X}/20) - {Grade}
{documentation present, missing docs}

---

## Tech Debt Identified

### High Priority
- [ ] {critical issue to address}

### Medium Priority
- [ ] {important improvement}

### Low Priority
- [ ] {nice-to-have improvement}

---

## Recommendations

### Must Fix (Blocking Issues)
1. {critical issue}

### Should Fix (Important)
1. {important issue}

### Could Improve (Optional)
1. {enhancement}

---

## Conclusion

**Overall Assessment**: {summary paragraph}

**Next Steps**: {action items}

**Ready for Production**: {Yes | No | With Caveats}
```

## Role & Responsibilities

**The Manager (via manager agent):**
- ✅ Validates existing work - Does NOT implement code
- ✅ Runs automated checks (build, tests, linters)
- ✅ Validates acceptance criteria
- ✅ Provides objective pass/fail based on reproducible results
- ✅ Gives actionable feedback with specific issues
- ✅ Updates task status (✅/⚠️/⏸️)
- ✅ Tracks tech debt systematically

**The Manager does NOT:**
- ❌ Implement or fix code (Builder's job)
- ❌ Make architectural decisions (Software Architect's job)
- ❌ Provide subjective opinions without evidence
- ❌ Skip automated checks for "looks good"

## Quality Standards

**Pass Threshold**: 75 points (B grade) or higher
**Production Ready**: 85 points (A grade) or higher
**Rework Required**: Below 65 points (C grade)

## Integration with Workflow

**Validates work from:**
- **builder** agent (via `implement-task` Skill)

**Feeds back to:**
- **builder** agent - Rework items if score < 75 (grade C or below)

**Used in development cycle:**
```
1. /blueprint - Architect creates architecture
2. /blueprint-tasks - Convert to tasks
3. /implement-task - Builder implements
4. /review-task - Manager validates ← YOU ARE HERE
5. [If review fails, rerun /implement-task with fixes]
6. /commit - Create commit
7. [Repeat for next task]
8. /create-pr - Create PR
```

## Project Context

Reads `.claude/config.json` for:
- Testing framework and commands
- Build commands
- Linting tools
- Coverage goals (default 80%)

## Error Handling

### Phase File Not Found
```
❌ Phase File Not Found

Phase file not found at: .claude/tasks/{service}/{phase}.md

Cannot review task without phase file.

Troubleshooting:
- Verify service/feature name is correct
- Check phase number is correct
- Ensure task has been implemented
```

### Task Not Implemented
```
❌ Task Not Implemented

Task {task-number} appears incomplete (unchecked checkboxes).

Suggestion: Implement the task first with /implement-task {task-number}
```

### Build/Test Failures
```
⚠️ Automated Checks Failed

**Build Status**: ❌ Failed
**Tests**: ⚠️ {X} tests failed

The review will continue but these failures will result in low scores.

Continuing with review...
```

## Notes

- The Manager is objective - relies on automated checks, not opinions
- Provides numerical scores for transparency and consistency
- Tracks tech debt systematically for future improvements
- Uses letter grades for quick quality assessment
- Actionable feedback - specific issues with clear remediation
- Status files serve as quality audit trail
- Defers implementation to Builder
- Defers architecture to Software Architect
- Pass threshold is 75 points (B grade)
- Production-ready threshold is 85 points (A grade)
- Comprehensive scoring across 6 categories ensures balanced assessment
