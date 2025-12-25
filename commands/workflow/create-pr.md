# Create Pull Request Command

Create a GitHub Pull Request with intelligent commit analysis and template population.

## Command Format

```bash
/create-pr [optional: custom title]
```

**Examples:**
```bash
/create-pr
/create-pr "Payment Service Phase 1 Implementation"
/create-pr "Fix: Authentication Bug in Token Validation"
```

## Step-by-Step Process

### 1. Pre-flight Validation

Run these checks:

```bash
# Check current branch
git branch --show-current

# Check for uncommitted changes
git status --short

# Check if branch has remote tracking
git rev-parse --abbrev-ref @{upstream} 2>/dev/null || echo "no-upstream"

# Get base branch (usually main)
git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main"
```

**Validation rules:**
- ❌ Cannot be on `main` or `master` branch
- ⚠️ Warn if uncommitted changes exist (suggest `/commit` first)
- ✅ Branch must have at least 1 commit ahead of base branch
- ✅ Ensure `gh` CLI is installed and authenticated

**If validation fails**, report error and stop.

### 2. Gather Git Context

Collect information about the changes:

```bash
# Get base branch
BASE_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')

# Get commits since divergence
git log ${BASE_BRANCH}..HEAD --oneline

# Get detailed commit info
git log ${BASE_BRANCH}..HEAD --format="%h|%s|%b"

# Get file change summary
git diff --stat ${BASE_BRANCH}..HEAD

# Get list of changed files with status
git diff --name-status ${BASE_BRANCH}..HEAD

# Count additions and deletions
git diff --shortstat ${BASE_BRANCH}..HEAD
```

### 3. Analyze Commits and Changes

#### Parse Commit Messages

For each commit, extract:
- **Type**: feat, fix, docs, chore, refactor, test, etc.
- **Scope**: (optional) what area was changed
- **Subject**: what was done
- **Body**: (optional) why it was done

**Example parsing:**
```
feat(payment): add Stripe integration

Implemented Stripe payment processing with:
- Webhook handling
- Error recovery
- Retry logic

Implements task payment-service/phase1#2.1
```

Parsed as:
- Type: `feat` → New Feature
- Scope: `payment`
- Subject: "add Stripe integration"
- Body: Implementation details
- Task reference: `payment-service/phase1#2.1`

#### Detect Blueprint/Task References

Check for references in:

**1. Branch name patterns:**
```
feature/payment-service-phase1 → payment-service/phase1
feature/user-profile-fix → user-profile
bugfix/auth-token-validation → (no blueprint)
```

**2. Commit messages:**
- Task references: `#2.1`, `phase1#2.1`, `task 2.1`
- Blueprint files: `.claude/blueprints/payment-service-blueprint.md`

**3. Changed files:**
- `.claude/tasks/{service}/{phase}.md` → Task file updated
- Check task file for checkbox completion

#### Categorize File Changes

Group changed files by:
- **Source code**: `src/`, `lib/`, `app/`
- **Tests**: `test/`, `tests/`, `__tests__/`, `*.test.*`, `*.spec.*`
- **Documentation**: `*.md`, `docs/`
- **Configuration**: `*.config.*`, `*.json`, `*.yaml`
- **Infrastructure**: `Dockerfile`, `docker-compose.yml`, `.github/`, `terraform/`
- **Database**: `migrations/`, `schema.sql`
- **Dependencies**: `package.json`, `*.csproj`, `requirements.txt`, `go.mod`

### 4. Generate PR Title

**If custom title provided:**
Use it as-is.

**If no custom title:**
Generate from commits:

**Single commit:**
```
feat(payment): add Stripe integration
→ "Add Stripe integration"
```

**Multiple commits of same type:**
```
feat(payment): add payment controller
feat(payment): add error handling
feat(payment): add tests
→ "Payment: Add Stripe integration with error handling and tests"
```

**Multiple types:**
```
feat(payment): add Payment entity
fix(payment): resolve validation bug
docs(payment): update API docs
→ "Payment Service: Implement entity, fix validation, update docs"
```

**Pattern:** `{scope}: {summary of changes}`

### 5. Read PR Template (If Exists)

Check for PR template:
```bash
# Check common locations
.github/pull_request_template.md
.github/PULL_REQUEST_TEMPLATE.md
docs/pull_request_template.md
PULL_REQUEST_TEMPLATE.md
```

**If template exists:**
Read it and identify sections to populate

**If no template:**
Use default template (see below)

### 6. Populate PR Description

Build PR description by populating template sections or creating default structure:

#### Default Template Structure

```markdown
# Pull Request

## Summary

{2-3 bullet points summarizing changes}

## Type of Change

- [ ] New Feature
- [ ] Bug Fix
- [ ] Refactor
- [ ] Documentation
- [ ] Performance
- [ ] Tests
- [ ] Infrastructure

## Changes Made

{Detailed list of changes grouped by area}

## Blueprint/Task Reference

{If applicable: blueprint and task references}

## Why This Change?

{Explanation from commit bodies}

## Testing

- [ ] Unit tests added/updated
- [ ] Integration tests added/updated
- [ ] Manual testing completed

### Test Commands
```bash
{test commands run}
```

## Architecture Impact

- [ ] API changes
- [ ] Database schema changes
- [ ] New dependencies
- [ ] Breaking changes

## Checklist

- [ ] Code follows style guidelines
- [ ] Self-reviewed the code
- [ ] Comments added for complex logic
- [ ] Tests pass locally
- [ ] Documentation updated

---

🤖 Generated with Claude Code
```

#### Populate Summary

Generate 2-3 bullet points from commit messages:

```markdown
## Summary

- Implemented Stripe payment processing in Payment Service
- Added webhook handling for payment events
- Included comprehensive error handling and retry logic
```

#### Auto-check Type of Change

Based on commit types:

| Commit Type | Checkbox |
|-------------|----------|
| `feat` | ✅ New Feature |
| `fix` | ✅ Bug Fix |
| `refactor` | ✅ Refactor |
| `docs` | ✅ Documentation |
| `perf` | ✅ Performance |
| `test` | ✅ Tests |
| `ci`, `build` | ✅ Infrastructure |

#### Populate Changes Made

Group by file categories:

```markdown
## Changes Made

### Payment Service
- Added `PaymentController` with 5 REST endpoints
- Implemented Stripe SDK integration
- Added webhook signature verification

### Database
- Created payments table migration
- Added indexes for customer_id and status

### Tests
- Added 12 unit tests for payment controller
- Added 5 integration tests for Stripe webhook handling
```

#### Detect Blueprint Reference

```markdown
## Blueprint/Task Reference

- Blueprint: `.claude/blueprints/payment-service-blueprint.md`
- Tasks Completed:
  - ✅ `payment-service/phase1#1.1` - Project setup
  - ✅ `payment-service/phase1#2.1` - Payment entity
  - ✅ `payment-service/phase1#2.2` - Stripe integration
```

#### Extract "Why"

From commit bodies:

```markdown
## Why This Change?

This implements Phase 1 of the Payment Service blueprint, establishing
the foundation for payment processing across the platform. Stripe was
chosen for its robust API and webhook support for async event handling.
```

#### Auto-detect Testing Coverage

```markdown
## Testing

- [x] Unit tests added/updated (12 tests in PaymentControllerTests)
- [x] Integration tests added/updated (5 webhook tests)
- [x] Manual testing completed (tested via Postman)

### Test Commands
```bash
npm test
# ✅ 17/17 tests passed
# Coverage: 85%
```
```

#### Detect Architecture Impact

```markdown
## Architecture Impact

- [x] API changes (documented)
  - Added 5 new endpoints: POST /payments, GET /payments/:id, etc.
- [x] Database schema changes (migration included)
  - Migration: `20250115_create_payments_table.sql`
- [x] New dependencies
  - stripe@14.14.0 - Payment processing SDK
- [ ] No breaking changes
```

### 7. Push Branch (If Needed)

```bash
# Check if branch is pushed
git rev-parse --abbrev-ref @{upstream} 2>/dev/null

# If no upstream, push with tracking
if [ $? -ne 0 ]; then
  git push -u origin $(git branch --show-current)
fi

# If branch exists but behind, warn user
git rev-list --count @{upstream}..HEAD
```

### 8. Create Pull Request

Use GitHub CLI to create PR:

```bash
gh pr create \
  --title "Your Generated Title Here" \
  --body "$(cat <<'EOF'
# Your Populated PR Description

{All the populated content from step 6}

---

🤖 Generated with Claude Code
EOF
)"
```

**Important:**
- Use heredoc for proper formatting
- Preserve markdown formatting
- Include all populated sections

### 9. Return PR Information

After successful creation:

```markdown
## 🎉 Pull Request Created!

**PR URL:** https://github.com/{org}/{repo}/pull/{number}

**Title:** {pr-title}

**Summary:**
- {X} files changed (+{additions}, -{deletions})
- {Y} commits
- {Z} tests added
- Blueprint: {blueprint-ref} (if applicable)

**Next Steps:**
1. Review the PR description and make manual adjustments if needed
2. Request reviews from team members:
   `gh pr edit {number} --add-reviewer @username`
3. Address any CI/CD feedback
4. Merge when approved! 🚀

**Quick Commands:**
- View PR: `gh pr view {number} --web`
- Check CI status: `gh pr checks {number}`
- Update PR: `gh pr edit {number}`
```

## Configuration

Read from `.claude/config.json` if available:

```json
{
  "git": {
    "prTemplate": ".github/pull_request_template.md",
    "baseBranch": "main",
    "detectBlueprintRefs": true,
    "includeAttribution": true,
    "autoAssignReviewers": false,
    "defaultReviewers": ["@username"]
  }
}
```

## Error Handling

### No Commits Ahead
```
❌ Error: No new commits on branch '{branch-name}'
Nothing to create a PR for. Make some commits first!
```

### On Main Branch
```
❌ Error: Cannot create PR from 'main' branch
Create a feature branch first:
  git checkout -b feature/my-feature
```

### Uncommitted Changes
```
⚠️ Warning: You have uncommitted changes:
  M src/controllers/PaymentController.ts

Commit them first using /commit, or stash them:
  git add . && git commit -m "Your message"
```

### GitHub CLI Not Installed
```
❌ Error: GitHub CLI (gh) is not installed
Install it: https://cli.github.com/
Or create PR manually via GitHub web UI
```

### Not Authenticated
```
❌ Error: Not authenticated with GitHub CLI
Run: gh auth login
```

## Advanced Options

Support additional parameters:

```bash
# Default: Create PR against main
/create-pr

# Custom title
/create-pr "Phase 1 Complete: Payment Service Foundation"

# Draft mode
/create-pr --draft

# Custom base branch
/create-pr --base develop

# With reviewers
/create-pr --reviewer @johndoe,@janedoe

# Dry run (show description without creating)
/create-pr --dry-run
```

## Integration with Workflow

```
1. /blueprint              - Architect creates architecture
2. /blueprint-tasks        - Convert to phase-based tasks
3. /implement-task X.X     - Builder implements tasks
4. /review-task X.X        - Foreman validates
5. /commit                 - Create commits
6. [Repeat 3-5 for all tasks]
7. /create-pr              - Create PR ← YOU ARE HERE
8. [Review, approve, merge]
9. /trello-complete        - Mark complete (optional)
```

## Quality Checklist

Before creating PR, verify:
- [ ] Current branch is not main/master
- [ ] Branch has commits ahead of base
- [ ] No uncommitted changes (or warn user)
- [ ] PR template fully populated
- [ ] Blueprint reference accurate (if applicable)
- [ ] File changes accurately categorized
- [ ] Test coverage documented
- [ ] Architecture impact noted

---

**Now analyze the current branch, populate the PR template intelligently, and create a well-documented pull request!**
