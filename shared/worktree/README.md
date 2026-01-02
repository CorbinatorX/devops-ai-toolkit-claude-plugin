# Git Worktree Helpers for Claude Code Skills

Reusable patterns for git worktree operations in Skills. Enables autonomous development workflows where the agent works in isolated worktrees, independent of the user's main workspace.

## Overview

Git worktrees allow multiple working directories to share a single git repository. This module provides patterns for:
- Creating worktrees from remote repositories
- Setting up isolated development environments
- Managing worktree lifecycle (create, work, cleanup)
- Integration with pickup-* skills

## Configuration

Worktree settings are configured in `.claude/techops-config.json`:

```json
{
  "worktree": {
    "enabled": true,
    "base_path": "/home/{user}/workspace/github/agent-worktrees",
    "path_pattern": "{repo}-{workitemid}",
    "repo_cache_path": "/home/{user}/.claude/repos",
    "cleanup_on_pr_create": false,
    "cleanup_on_pr_merge": true,
    "fetch_before_create": true
  }
}
```

### Configuration Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `enabled` | boolean | `false` | Enable worktree mode for pickup-* skills |
| `base_path` | string | `/home/{user}/workspace/github/agent-worktrees` | Base directory for worktrees |
| `path_pattern` | string | `{repo}-{workitemid}` | Pattern for worktree directory name |
| `repo_cache_path` | string | `/home/{user}/.claude/repos` | Where to cache cloned repositories |
| `cleanup_on_pr_create` | boolean | `false` | Remove worktree after PR creation |
| `cleanup_on_pr_merge` | boolean | `true` | Remove worktree after PR is merged |
| `fetch_before_create` | boolean | `true` | Fetch latest from remote before creating worktree |

### Path Pattern Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `{user}` | Current system username | `corbinator` |
| `{repo}` | Repository name from work item | `infonexus-api` |
| `{workitemid}` | Work item ID | `25186` |
| `{branch_prefix}` | Branch type prefix | `feature`, `bug`, `refactor` |

## Worktree Creation Algorithm

### Full Algorithm

```markdown
create_autonomous_worktree(work_item_id, repository_field, branch_prefix, title_slug):

    # Step 1: Read and validate configuration
    config = read_techops_config(".claude/techops-config.json")
    if not config.worktree.enabled:
        return None  # Fall back to existing behavior

    # Step 2: Parse repository field
    # Format expected: "org/repo-name" or "repo-name" or full URL
    repo_name = parse_repository_name(repository_field)
    repo_url = resolve_repository_url(repository_field)

    # Step 3: Resolve paths
    user = get_current_user()  # whoami
    base_path = config.worktree.base_path.replace("{user}", user)
    worktree_name = config.worktree.path_pattern
        .replace("{repo}", repo_name)
        .replace("{workitemid}", work_item_id)
    worktree_path = "{base_path}/{worktree_name}"

    # Step 4: Ensure base repository exists (for worktree source)
    repo_cache = config.worktree.repo_cache_path.replace("{user}", user)
    cached_repo_path = "{repo_cache}/{repo_name}"

    if not exists(cached_repo_path):
        # Clone the repository to cache
        git clone --bare {repo_url} {cached_repo_path}
    else:
        # Update the cached repository
        cd {cached_repo_path}
        git fetch --all --prune

    # Step 5: Ensure base_path directory exists
    mkdir -p {base_path}

    # Step 6: Check if worktree already exists
    if exists(worktree_path):
        cd {worktree_path}
        echo "Worktree already exists, checking out existing worktree"
        return worktree_path

    # Step 7: Create worktree with new branch
    branch_name = "{branch_prefix}/{work_item_id}-{title_slug}"
    cd {cached_repo_path}

    # Fetch latest if configured
    if config.worktree.fetch_before_create:
        git fetch origin main:main || git fetch origin master:master

    # Create worktree with new branch from main
    git worktree add -b {branch_name} {worktree_path} main
    # If main doesn't exist, try master
    # git worktree add -b {branch_name} {worktree_path} master

    # Step 8: Set up remote tracking in worktree
    cd {worktree_path}
    git push -u origin {branch_name}

    # Step 9: Return worktree path for skill to use
    return worktree_path
```

### Bash Implementation Reference

```bash
create_autonomous_worktree() {
    local work_item_id="$1"
    local repository_field="$2"
    local branch_prefix="$3"
    local title_slug="$4"

    # Read config (simplified - actual implementation reads JSON)
    local worktree_enabled=$(jq -r '.worktree.enabled // false' .claude/techops-config.json)
    if [ "$worktree_enabled" != "true" ]; then
        echo ""
        return 0
    fi

    # Get current user
    local user=$(whoami)

    # Parse repository name from field
    local repo_name=$(echo "$repository_field" | sed 's|.*/||' | sed 's|\.git$||')

    # Build paths
    local base_path="/home/${user}/workspace/github/agent-worktrees"
    local repo_cache="/home/${user}/.claude/repos"
    local worktree_path="${base_path}/${repo_name}-${work_item_id}"
    local cached_repo="${repo_cache}/${repo_name}.git"
    local branch_name="${branch_prefix}/${work_item_id}-${title_slug}"

    # Ensure directories exist
    mkdir -p "$base_path"
    mkdir -p "$repo_cache"

    # Check if worktree already exists
    if [ -d "$worktree_path" ]; then
        echo "$worktree_path"
        return 0
    fi

    # Ensure bare repository cache exists
    if [ ! -d "$cached_repo" ]; then
        local repo_url="git@github.com:${repository_field}.git"
        git clone --bare "$repo_url" "$cached_repo"
    else
        git -C "$cached_repo" fetch --all --prune
    fi

    # Fetch latest main
    git -C "$cached_repo" fetch origin main:main 2>/dev/null || \
        git -C "$cached_repo" fetch origin master:master 2>/dev/null

    # Create worktree with new branch
    git -C "$cached_repo" worktree add -b "$branch_name" "$worktree_path" main 2>/dev/null || \
        git -C "$cached_repo" worktree add -b "$branch_name" "$worktree_path" master

    # Set up remote tracking
    cd "$worktree_path"
    git push -u origin "$branch_name" 2>/dev/null || true

    echo "$worktree_path"
}

# Usage
worktree_path=$(create_autonomous_worktree "25186" "Infonetica/infonexus-api" "feature" "git-worktree-support")
if [ -n "$worktree_path" ]; then
    cd "$worktree_path"
    echo "Working in worktree: $worktree_path"
fi
```

## Repository Field Parsing

The work item's `repository` field may contain various formats. Here's how to parse them:

```markdown
parse_repository_name(repository_field) -> repo_name:
    # Format 1: "Infonetica/infonexus-api" -> "infonexus-api"
    # Format 2: "infonexus-api" -> "infonexus-api"
    # Format 3: "https://github.com/Infonetica/infonexus-api" -> "infonexus-api"
    # Format 4: "git@github.com:Infonetica/infonexus-api.git" -> "infonexus-api"

    1. Remove trailing ".git" if present
    2. Extract last path segment (after final "/" or ":")
    3. Return cleaned name
```

```bash
parse_repo_name() {
    local field="$1"
    # Remove .git suffix, then get last segment
    echo "$field" | sed 's|\.git$||' | sed 's|.*[/:]||'
}

# Examples:
# parse_repo_name "Infonetica/infonexus-api" -> "infonexus-api"
# parse_repo_name "git@github.com:Infonetica/infonexus-api.git" -> "infonexus-api"
```

## Worktree Cleanup Patterns

### Pattern 1: Manual Cleanup

```bash
cleanup_worktree() {
    local worktree_path="$1"
    local cached_repo="$2"

    if [ -d "$worktree_path" ]; then
        # Remove worktree registration
        git -C "$cached_repo" worktree remove "$worktree_path" --force

        # Verify removal
        if [ ! -d "$worktree_path" ]; then
            echo "Worktree removed: $worktree_path"
        else
            # Force remove directory if worktree command failed
            rm -rf "$worktree_path"
            git -C "$cached_repo" worktree prune
            echo "Worktree force-removed: $worktree_path"
        fi
    fi
}
```

### Pattern 2: Cleanup After PR Creation

```markdown
If config.worktree.cleanup_on_pr_create is true:
    After successfully creating PR:
    1. Get worktree path from context
    2. Call cleanup_worktree()
    3. Log cleanup action
```

### Pattern 3: Cleanup After PR Merge

```markdown
If config.worktree.cleanup_on_pr_merge is true:
    This requires monitoring - typically handled by:
    1. User manually runs cleanup command
    2. Or: Check PR status before each pickup and clean merged worktrees
```

### Pattern 4: List and Prune Worktrees

```bash
# List all worktrees for a cached repo
list_worktrees() {
    local cached_repo="$1"
    git -C "$cached_repo" worktree list
}

# Prune stale worktree references
prune_worktrees() {
    local cached_repo="$1"
    git -C "$cached_repo" worktree prune -v
}

# Clean all worktrees for a specific work item
cleanup_workitem_worktrees() {
    local base_path="$1"
    local work_item_id="$2"

    find "$base_path" -maxdepth 1 -type d -name "*-${work_item_id}" -exec rm -rf {} \;
}
```

## Working in Worktrees

Once a worktree is created, all git operations work normally:

```bash
# In the worktree directory
cd /home/user/workspace/github/agent-worktrees/infonexus-api-25186

# Normal git operations
git status
git add .
git commit -m "feat: add worktree support"
git push origin feature/25186-git-worktree-support

# Create PR (using gh CLI)
gh pr create --title "Feature: Git Worktree Support" --body "..."
```

## Integration with Pickup Skills

### Modified Step 8: Create Git Branch (with Worktree Support)

```markdown
### Step 8: Create Git Branch

**Check for worktree mode:**

1. Read `.claude/techops-config.json` from consuming repo
2. Check if `worktree.enabled` is `true`

**If worktree mode enabled:**

1. Get repository from work item field: `Custom.Repository` or `repository`
2. Parse repository name and URL
3. Create worktree using algorithm above
4. Change working directory to worktree path
5. Continue with implementation in isolated environment

**If worktree mode disabled (default):**

Use existing behavior - create branch in current working directory.

**Worktree Creation Commands:**

```bash
# Read config
worktree_enabled=$(cat .claude/techops-config.json | jq -r '.worktree.enabled // false')

if [ "$worktree_enabled" = "true" ]; then
    # Get repository from work item (passed as variable)
    repository_field="{work_item.Custom.Repository}"

    # Create worktree
    worktree_path=$(create_autonomous_worktree \
        "{work_item_id}" \
        "$repository_field" \
        "{branch_prefix}" \
        "{title_slug}")

    if [ -n "$worktree_path" ]; then
        cd "$worktree_path"
        echo "## Worktree Created"
        echo ""
        echo "Working in isolated worktree: \`$worktree_path\`"
        echo ""
        echo "Branch: \`{branch_prefix}/{work_item_id}-{title_slug}\`"
    fi
else
    # Existing behavior
    git checkout -b {branch_prefix}/{work_item_id}-{title_slug}
fi
```

**Output (worktree mode):**

```markdown
## Worktree Created

Working in isolated worktree: `/home/corbinator/workspace/github/agent-worktrees/infonexus-api-25186`

Branch: `feature/25186-git-worktree-support`

This worktree is independent of your main workspace. All changes will be made here.
```
```

## Error Handling

### Worktree Creation Failed

```markdown
## Worktree Creation Failed

**Error:** {error_message}

**Troubleshooting:**

1. Verify repository field is populated on work item
2. Check network connectivity to git remote
3. Ensure you have access to the repository
4. Verify base path is writable: `{base_path}`

**Fallback:**
Continuing with standard branch creation in current directory.
```

### Repository Clone Failed

```markdown
## Repository Clone Failed

**Error:** Could not clone repository: {repository_url}

**Possible causes:**
- Repository doesn't exist
- No access permissions
- Network connectivity issues
- Invalid repository URL format

**Repository field value:** `{repository_field}`

**Troubleshooting:**
1. Verify the repository exists and you have access
2. Check SSH keys or credentials are configured
3. Try cloning manually: `git clone {repository_url}`
```

### Worktree Already Exists

```markdown
## Worktree Already Exists

Worktree for work item #{work_item_id} already exists at:
`{worktree_path}`

Checking out existing worktree and continuing.

If you want to start fresh:
```bash
rm -rf {worktree_path}
git -C {cached_repo} worktree prune
```
Then run the pickup command again.
```

## Directory Structure

When worktree mode is enabled, the following structure is created:

```
/home/{user}/
├── .claude/
│   └── repos/                          # Cached bare repositories
│       ├── infonexus-api.git/
│       ├── infonexus-application.git/
│       └── my-project.git/
└── workspace/
    └── github/
        ├── repos/                      # User's normal workspaces
        │   ├── infonexus-api/
        │   └── my-project/
        └── agent-worktrees/            # Agent worktrees (isolated)
            ├── infonexus-api-25186/    # feature/25186-...
            ├── infonexus-api-25200/    # bug/25200-...
            └── my-project-25300/       # refactor/25300-...
```

## Benefits of Worktree Mode

1. **Parallel Development**: Work on multiple items simultaneously
2. **Clean Isolation**: No interference with user's active work
3. **Fresh State**: Always starts from latest main branch
4. **Autonomous Operation**: Agent works independently
5. **Better CI Integration**: Clean branches from known good state
6. **Easy Cleanup**: Remove worktree without affecting other work

## Usage in Skills

Skills should check for worktree configuration and adapt their behavior:

```markdown
# In SKILL.md Step 8

### Step 8: Create Git Branch

**Reference**: See `.claude/shared/worktree/README.md` for worktree patterns.

1. Check if worktree mode is enabled in config
2. If enabled:
   - Read repository field from work item
   - Create worktree using shared patterns
   - Work in isolated directory
3. If disabled:
   - Use existing branch creation in current directory
```

## Notes

- Worktree mode is opt-in via configuration
- Bare repository cache reduces clone time for repeated use
- Worktrees share git objects with cached repo (space efficient)
- Each worktree has its own working directory and index
- Branches created in worktrees are immediately available in main repo
- Remote push works normally from worktrees
- Compatible with all git operations (commit, push, PR creation)
