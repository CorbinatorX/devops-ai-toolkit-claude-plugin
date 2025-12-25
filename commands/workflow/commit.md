# Smart Commit Command

Analyze the current git diff and create an appropriate commit message following conventional commit format.

## Conventional Commit Prefixes

Use one of these prefixes based on the type of change:

- **feat:** for new features (✨)
- **fix:** for bug fixes (🐛)
- **docs:** for documentation (📚)
- **chore:** for maintenance tasks (🔧)
- **refactor:** for code refactoring (♻️)
- **test:** for adding tests (🧪)
- **style:** for formatting changes (💄)
- **perf:** for performance improvements (⚡)
- **ci:** for CI/CD changes (👷)
- **build:** for build system changes (🔨)

## Process

### 1. Check Repository State

```bash
# See what's changed
git status

# IMPORTANT: Check if there are actually changes to commit
# If working tree is clean, inform user
```

**If no changes exist**:
- Check last commit: `git log -1 --name-status`
- Inform user: "Repository is clean. No changes to commit."

### 2. Stage Changes (If Needed)

If there are unstaged changes:
```bash
git add .
```

**Note**: Only stage files that should be committed. Check for:
- ❌ Sensitive files (.env, credentials, secrets)
- ❌ Build artifacts (dist/, build/, bin/, obj/)
- ❌ Dependencies (node_modules/, vendor/)
- ❌ IDE files (.vscode/, .idea/)

Warn user if sensitive files are about to be committed.

### 3. Analyze Changes

```bash
# See what will be committed
git diff --cached

# Get file statistics
git diff --cached --stat
```

Analyze and determine:
- **What type** of change this is (feat, fix, docs, etc.)
- **What was accomplished** (1-2 sentence summary)
- **Which files/components** are affected
- **Why** this change was necessary (if apparent)

### 4. Generate Commit Message

**Format:**
```
<type>(<scope>): <subject>

<body>

<footer>
```

**Rules:**
- **Subject line**: Imperative mood, max 72 characters
- **Scope**: Optional, component/module affected
- **Body**: Explain what and why (not how), wrap at 72 characters
- **Footer**: Breaking changes, issue references

**Examples:**

**Simple commit:**
```
feat(auth): add JWT token validation

Implement middleware to validate JWT tokens on protected routes.
Includes error handling for expired and invalid tokens.
```

**Bug fix:**
```
fix(payment): resolve Stripe webhook signature verification

The webhook signature was failing due to incorrect encoding.
Updated to use raw body buffer as required by Stripe.

Fixes #123
```

**Documentation:**
```
docs(api): update authentication endpoint documentation

Add examples for OAuth flow and clarify JWT token format.
```

**Breaking change:**
```
feat(api)!: migrate to v2 authentication

BREAKING CHANGE: Authentication now requires OAuth 2.0.
API key authentication is no longer supported.

Migration guide in MIGRATION.md
```

### 5. Handle Large Commits

When a commit includes many files (>15) or multiple areas, structure as:

```
<type>: <high-level summary>

<Area 1>:
- Specific change 1
- Specific change 2

<Area 2>:
- Specific change 1
- Specific change 2

<Additional context if needed>
```

**Example:**
```
feat: implement user profile management

User Profile API:
- Add GET /api/users/:id endpoint
- Add PUT /api/users/:id endpoint
- Implement user data validation

Database:
- Create users table migration
- Add indexes for email and username

Tests:
- Add unit tests for user service
- Add integration tests for user endpoints
```

### 6. Detect Blueprint/Task References

Check for blueprint or task references in:
- Branch name (e.g., `feature/payment-service-phase1`)
- Modified files (e.g., `.claude/tasks/payment-service/phase1.md`)

If found, include in commit body:
```
feat(payment): implement payment processing service

Implements Phase 1, Task 2.1 from payment-service blueprint.
See .claude/tasks/payment-service/phase1.md for details.
```

### 7. Create Commit

**Use heredoc for proper formatting:**

```bash
git commit -m "$(cat <<'EOF'
<type>(<scope>): <subject>

<body with multiple lines
wrapped at 72 characters
for readability>

<footer>

🤖 Generated with Claude Code

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

**IMPORTANT**: Always include Claude Code attribution at the end.

### 8. Verify Commit

After committing:
```bash
# Verify commit was created
git log -1 --oneline

# Show commit details
git show --stat
```

Report to user:
```markdown
## ✅ Commit Created

**Message:**
```
<your generated message>
```

**Files Changed:** {X} files (+{additions}, -{deletions})

**Commit Hash:** {hash}

**Next Steps:**
- Review commit: `git show`
- Amend if needed: `git commit --amend`
- Continue work: `/implement-task {next-task}`
- Create PR when phase complete: `/create-pr`
```

## Guidelines

### Subject Line
- **Be specific**: "fix: resolve email validation" not "fix: bug fix"
- **Use imperative mood**: "add", "fix", "update" not "added", "fixed", "updated"
- **No period** at the end
- **Keep under 72 characters**
- **Use present tense**: "fix bug" not "fixed bug"

### Body
- Explain **what and why**, not how
- Reference issues: "Fixes #123", "Closes #456"
- Mention breaking changes: "BREAKING CHANGE: ..."
- Wrap at 72 characters
- Separate from subject with blank line

### Scope
Common scopes (adapt to your project):
- Component names: `(auth)`, `(payment)`, `(user)`
- Layers: `(api)`, `(database)`, `(ui)`
- Services: `(gateway)`, `(events)`, `(notifications)`

### Type Selection Guide

**feat**: New functionality added
```
feat(api): add user registration endpoint
feat(ui): implement dark mode toggle
```

**fix**: Bug fixes
```
fix(auth): resolve token expiration handling
fix(payment): correct amount calculation
```

**docs**: Documentation only
```
docs(readme): update installation instructions
docs(api): add endpoint examples
```

**refactor**: Code restructuring (no functional change)
```
refactor(services): extract payment logic to separate class
refactor(utils): simplify date formatting functions
```

**test**: Adding or updating tests
```
test(payment): add unit tests for refund logic
test(auth): increase coverage for token validation
```

**chore**: Maintenance, dependencies, config
```
chore(deps): upgrade to React 18
chore(ci): update GitHub Actions workflow
```

**perf**: Performance improvements
```
perf(api): optimize database queries
perf(ui): implement virtualization for large lists
```

## Special Cases

### Multiple Types in One Commit

If genuinely necessary (though discouraged), use the primary type:
```
feat(api): add user endpoints and fix validation

New Features:
- POST /api/users endpoint
- GET /api/users/:id endpoint

Bug Fixes:
- Fixed email validation regex
- Resolved phone number formatting
```

**Better approach**: Split into multiple commits

### Work-in-Progress Commits

```
wip: payment integration in progress

Partial implementation of Stripe payment processing.
Not ready for review yet.
```

Then squash before merging.

### Merge Commits

Let git generate merge commit messages, or:
```
merge: integrate payment-service-phase1 into main

Merges PR #123: Payment Service Phase 1 Implementation
```

## Configuration Options

Read from `.claude/config.json` if available:

```json
{
  "git": {
    "conventionalCommits": true,
    "includeAttribution": true,
    "maxSubjectLength": 72,
    "bodyWrapLength": 72,
    "includeEmoji": false,
    "scopes": ["api", "ui", "auth", "payment"],
    "detectBlueprintRefs": true
  }
}
```

## Validation

Before committing, check:
- [ ] Working directory has changes
- [ ] No sensitive files being committed
- [ ] Conventional commit format correct
- [ ] Subject line under 72 characters
- [ ] Body wrapped at 72 characters
- [ ] Blueprint/task reference included (if applicable)
- [ ] Issue references included (if applicable)
- [ ] Claude Code attribution included

## Integration with Workflow

```
1. /implement-task X.X - Builder implements
2. /review-task X.X    - Foreman validates
3. /commit             - Create smart commit ← YOU ARE HERE
4. [Repeat 1-3 for all tasks in phase]
5. /create-pr          - Create pull request
```

---

**Now analyze the current git diff and create an intelligent, well-formatted conventional commit following these guidelines.**
