# Git Helpers for Claude Code Skills

Reusable patterns for git operations in Skills, particularly branch creation and slug generation.

## Branch Slug Generation Algorithm

**Purpose**: Generate clean, URL-safe branch slugs from work item titles.

**Pattern**: `{prefix}/{work_item_id}-{slug}`

Examples:
- Bug: `bug/25123-feature-flags-dont-display-for-sites`
- Feature: `feature/25200-users-and-orders-api-returns-500-error`

### Algorithm Steps

```markdown
generate_branch_slug(title: str, max_length: int = 50) -> str:
    1. Convert to lowercase
    2. Replace special characters:
       - ' (apostrophes) → remove
       - " (quotes) → remove
       - / → -
       - \ → -
       - & → and
       - + → plus
       - % → percent
       - Other punctuation → remove
    3. Replace spaces and underscores with hyphens
    4. Remove all non-alphanumeric characters except hyphens
    5. Replace multiple consecutive hyphens with single hyphen
    6. Trim hyphens from start and end
    7. Truncate to max_length at word boundary:
       - If longer than max_length, truncate at max_length
       - Try to break at last hyphen after position 30 (word boundary)
       - If no hyphen found after position 30, just cut at max_length
    8. Return slug
```

### Slug Generation Examples

| Input Title | Output Slug |
|-------------|-------------|
| "Feature flags don't display for sites" | `feature-flags-dont-display-for-sites` |
| "P95/P99 response times not displaying" | `p95-p99-response-times-not-displaying` |
| "Users & Orders API returns 500 error" | `users-and-orders-api-returns-500-error` |
| "Fix: Can't save 100% complete status" | `fix-cant-save-100percent-complete-status` |
| "Add support for UTF-8 encoding" | `add-support-for-utf-8-encoding` |
| "Update requirements.txt + dependencies" | `update-requirementstxt-plus-dependencies` |

### Edge Cases

| Input | Output | Note |
|-------|--------|------|
| "   Spaces   " | `spaces` | Trim and collapse |
| "Multiple---Hyphens" | `multiple-hyphens` | Collapse hyphens |
| "UPPERCASE TITLE" | `uppercase-title` | Lowercase |
| "Special!@#$%Characters" | `specialpercentcharacters` | Remove special chars |
| "Very long title that exceeds fifty character limit and should be truncated properly" | `very-long-title-that-exceeds-fifty-character` | Truncate at 50 |

### Implementation Reference (Bash)

```bash
generate_branch_slug() {
    local title="$1"
    local max_length="${2:-50}"

    # Convert to lowercase
    local slug=$(echo "$title" | tr '[:upper:]' '[:lower:]')

    # Replace special characters
    slug=$(echo "$slug" | sed "s/'//g; s/\"//g")
    slug=$(echo "$slug" | sed 's/[\/\\]/-/g')
    slug=$(echo "$slug" | sed 's/&/and/g; s/+/plus/g; s/%/percent/g')

    # Replace spaces and underscores with hyphens
    slug=$(echo "$slug" | sed 's/[ _]/-/g')

    # Remove non-alphanumeric except hyphens
    slug=$(echo "$slug" | sed 's/[^a-z0-9-]//g')

    # Collapse multiple hyphens
    slug=$(echo "$slug" | sed 's/-\+/-/g')

    # Trim hyphens from ends
    slug=$(echo "$slug" | sed 's/^-//; s/-$//')

    # Truncate to max_length at word boundary
    if [ ${#slug} -gt $max_length ]; then
        truncated="${slug:0:$max_length}"
        # Try to find last hyphen after position 30
        last_hyphen=$(echo "$truncated" | awk -F- '{for(i=NF;i>0;i--) {pos+=length($i)+1; if(pos>20) {print length(slug)-pos; exit}}}')
        if [ -n "$last_hyphen" ] && [ $last_hyphen -gt 30 ]; then
            slug="${slug:0:$last_hyphen}"
        else
            slug="$truncated"
        fi
    fi

    echo "$slug"
}

# Usage
slug=$(generate_branch_slug "Feature flags don't display for sites")
# Returns: feature-flags-dont-display-for-sites
```

## Branch Creation Patterns

### Pattern 1: Create Bug Branch

```markdown
branch_name="bug/{work_item_id}-{slug}"

Example: bug/25123-feature-flags-dont-display-for-sites

Steps:
1. Generate slug from bug title
2. Construct branch_name: "bug/{id}-{slug}"
3. Check if branch exists:
   git rev-parse --verify "$branch_name" 2>/dev/null
4. If exists:
   - Checkout existing branch
   - Inform user: "Checking out existing branch: {branch_name}"
5. If not exists:
   - Create and checkout new branch from main
   - Inform user: "Created new branch: {branch_name}"
```

### Pattern 2: Create Feature Branch

```markdown
branch_name="feature/{work_item_id}-{slug}"

Example: feature/25200-users-and-orders-api-implementation

Steps: Same as bug branch but with "feature/" prefix
```

### Pattern 3: Check Branch Exists

```bash
# Check if branch exists locally
git rev-parse --verify "$branch_name" 2>/dev/null
if [ $? -eq 0 ]; then
    echo "Branch exists"
else
    echo "Branch does not exist"
fi
```

### Pattern 4: Create or Checkout Branch

```bash
# Unified pattern that handles both cases
create_or_checkout_branch() {
    local branch_name="$1"
    local from_branch="${2:-main}"

    if git rev-parse --verify "$branch_name" 2>/dev/null; then
        # Branch exists, checkout
        git checkout "$branch_name"
        echo "## 📂 Branch Already Exists"
        echo ""
        echo "Checking out existing branch: \`$branch_name\`"
        echo ""
        echo "This branch was likely created in a previous session."
    else
        # Branch doesn't exist, create
        git checkout -b "$branch_name"
        echo "## Git Branch Created"
        echo ""
        echo "Created and checked out new branch: \`$branch_name\`"
    fi
}

# Usage
create_or_checkout_branch "bug/25123-fix-display-issue" "main"
```

## Git Status and Diff Patterns

### Pattern: Check for Uncommitted Changes

```bash
# Check for any changes (staged or unstaged)
git status --short | grep -q '^[MADRCU]'
if [ $? -eq 0 ]; then
    echo "Uncommitted changes detected"
fi
```

### Pattern: Get Current Branch Name

```bash
current_branch=$(git branch --show-current)
echo "Current branch: $current_branch"
```

### Pattern: Check Commits Ahead of Main

```bash
commits_ahead=$(git rev-list --count main..HEAD 2>/dev/null || echo 0)
if [ $commits_ahead -gt 0 ]; then
    echo "You have $commits_ahead commit(s) ahead of main"
fi
```

### Pattern: Get Recent Commit Messages

```bash
# Get last 5 commit messages
git log -5 --oneline --no-decorate

# Get commits since branching from main
git log main..HEAD --oneline --no-decorate
```

## Error Handling Patterns

### Branch Creation Failed

```markdown
## ❌ Git Operation Failed

**Error**: {error_message}

Common issues:
- Uncommitted changes in working directory
- Branch name conflicts
- Git repository not initialized
- Detached HEAD state
- Remote sync issues

**Troubleshooting:**

Check working directory:
\`\`\`bash
git status
\`\`\`

If you have uncommitted changes:
\`\`\`bash
git stash
git stash list  # To see your stashes
\`\`\`

If branch name conflicts, try manually:
\`\`\`bash
git checkout -b {branch_name}
\`\`\`

After resolving git issues, you can continue.
```

### Detached HEAD State

```bash
# Check if in detached HEAD
git symbolic-ref -q HEAD
if [ $? -ne 0 ]; then
    echo "Warning: Detached HEAD state detected"
    echo "Consider checking out a branch: git checkout main"
fi
```

## Commit Message Patterns

### Conventional Commits

```markdown
Format: <type>(<scope>): <subject>

Types:
- feat: New feature
- fix: Bug fix
- docs: Documentation changes
- chore: Maintenance tasks
- refactor: Code refactoring
- test: Adding/updating tests
- perf: Performance improvements
- ci: CI/CD changes
- build: Build system changes

Examples:
- feat(api): add user authentication endpoint
- fix(ui): resolve pagination bug in user list
- docs(readme): update installation instructions
- refactor(database): optimize query performance
```

### Commit Attribution

All commits should include Claude Code attribution:

```markdown
<commit message>

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

## Usage in Skills

Skills should document git operations in their SKILL.md:

```markdown
# In SKILL.md

## Git Integration

This Skill uses git for branch management.

**Reference**: See `.claude/shared/git/README.md` for:
- Branch slug generation algorithm
- Branch creation patterns
- Error handling

**Git Operations**:
1. Generate branch slug from work item title
2. Create or checkout branch: {prefix}/{id}-{slug}
3. Verify branch creation success
```

## Testing

When implementing Skills that use git:

1. **Test slug generation**: Verify special characters handled correctly
2. **Test truncation**: Ensure slugs don't exceed 50 characters
3. **Test existing branches**: Verify checkout works, no duplication
4. **Test from different branches**: Create branches from main and feature branches
5. **Test with dirty working directory**: Handle uncommitted changes gracefully

## Branch Naming Conventions

| Work Item Type | Prefix | Example |
|----------------|--------|---------|
| TechOps Bug | `bug/` | `bug/25123-feature-flags-dont-display` |
| User Story | `feature/` | `feature/25200-user-authentication` |
| Task | `task/` | `task/25300-update-dependencies` |
| Blueprint | `feature/` | `feature/blueprint-payment-service` |

## Notes

- Always lowercase branch names
- Only alphanumeric and hyphens allowed
- Maximum slug length: 50 characters (excluding prefix and work item ID)
- Word boundary truncation preserves readability
- Checkout existing branches gracefully (no error)
- Always create branches from main unless specified otherwise
- Use Bash git commands, not git libraries (for Skills compatibility)
