---
name: implement-task
description: Implement specific tasks from phase files with strict scope discipline, following architecture blueprints exactly as specified
allowed-tools: Read, Write, Bash, Grep, Glob, Edit
auto-discover:
  - "implement task"
  - "build task"
  - "work on task"
  - "phase#"
  - "task #"
---

# Implement Task Skill

## Purpose

Focused implementation of specific tasks from phase files (`.claude/tasks/`) with strict scope and discipline. The Builder agent executes tasks exactly as specified in the blueprint, updating checkboxes and generating implementation reports.

This Skill delegates to the **builder** agent for focused, disciplined task execution.

## Auto-Discovery Triggers

This Skill automatically activates when users mention:
- "Implement task {service}/phase{N}#{task}"
- "Build task {number}"
- "Work on phase{N}#{task}"
- "Implement {service} task {number}"

## Example Invocations

```
"Implement task payment-service/phase1#2.1"
"Build task 3.5 from phase2"
"Work on phase1#4.2"
"Implement payment-service task 2.1"
```

## Task Reference Formats

**Full path**: `payment-service/phase1#3.1` - Service name, phase file, task number
**Short format**: `3.1` - If phase file context is clear from conversation
**With description**: `payment-service/phase1#3.1 Payment Entity Implementation`

## Workflow

### 1. Parse Task Reference

Extract:
- **Service/feature name**: e.g., `payment-service`, `user-profile`
- **Phase number**: e.g., `phase1`, `phase2`
- **Task number**: e.g., `3.1`, `4.2`, `2.5`

If short format provided, infer from context or ask user for clarification.

### 2. Read Phase File

**Location pattern**: `.claude/tasks/{service-or-feature-name}/{phase}.md`

Example: `.claude/tasks/payment-service/phase1.md`

Find the task section by searching for numbered headers: `#### {task-number}`

### 3. Extract Task Context

From task section, parse:

**Checkbox Tasks** (`- [ ]` or `- [x]`):
```markdown
- [ ] Create PaymentController
- [ ] Implement POST /api/payments endpoint
- [ ] Add error handling for payment failures
```

These are the work items to implement.

**Location Annotations**:
```markdown
**Location:** `src/controllers/PaymentController.ts`
```

**CRITICAL**: Only create/modify files mentioned in Location annotations.

**Commands**:
```markdown
**Commands:**
```bash
npm install stripe
npm run build
npm test
```
```

**Acceptance Criteria**:
```markdown
**Acceptance Criteria:**
- All endpoints functional
- Proper error handling
- Tests passing
```

**Code Examples**: Tasks often include example code - use as templates but adapt to project conventions.

### 4. Read Related Context (Minimal)

**IMPORTANT**: Stay focused. Only read:
1. The task section from phase file
2. The blueprint (if architectural context needed): `.claude/blueprints/{name}-blueprint.md`
3. Existing files (if modifying, not creating)
4. Config file: `.claude/config.json` for conventions

**DO NOT**:
- ❌ Read entire phase file (too much context)
- ❌ Read other services' code (unless task explicitly integrates)
- ❌ Browse codebase for patterns (use blueprint examples)

### 5. Delegate to Builder Agent

Invoke the **builder** agent to implement the task. The agent will:

**A. Run Setup Commands** (If Any)
Execute commands from task's **Commands:** section first.

**B. Create/Modify Files**
For each **Location** specified:
- **New file**: Use Write tool with full implementation
- **Existing file**: Read first, then use Edit tool for targeted changes

**C. Implement Checkbox Items**
Go through each `- [ ]` checkbox systematically.

**D. Write Tests** (If Specified)
If acceptance criteria or checkboxes mention tests, create test files.

**E. Validate Against Acceptance Criteria**
Before completion, verify each criterion is satisfied.

### 6. Update Phase File

Mark completed checkboxes:
```diff
- - [ ] Create PaymentController
+ - [x] Create PaymentController
- - [ ] Implement POST /api/payments endpoint
+ - [x] Implement POST /api/payments endpoint
```

Add completion note (optional):
```markdown
#### 3.1 Payment Controller Implementation ✅ COMPLETED (2025-01-15)

**Implementation Notes:**
- Created PaymentController with 5 endpoints
- Added Stripe integration with error handling
- All tests passing
```

### 7. Generate Implementation Report

```markdown
## 🔨 Builder Report: Task {task-number} Complete

**Task**: {task-title}
**Phase File**: `.claude/tasks/{service}/{phase}.md`
**Implementation Date**: {current-date}

### 📁 Files Created/Modified
1. **Created**: `{path}` ({lines} lines)
   - {summary of what was added}
2. **Modified**: `{path}` ({lines changed})
   - {summary of changes}

### ✅ Checkbox Completion
- [x] {checkbox 1}
- [x] {checkbox 2}
- [x] {checkbox 3}
**Completion**: {X}/{Y} checkboxes (100%)

### 🎯 Acceptance Criteria Status
- ✅ {criterion 1} (verified)
- ✅ {criterion 2} (verified)
**Criteria Met**: {X}/{Y} (100%)

### 🧪 Verification
**Build Status**: ✅ Build succeeded (0 warnings, 0 errors)
**Tests**: ✅ {X} tests passed

### 📝 Implementation Notes
- {Note about approach}
- {Note about challenges}

### 🔄 Next Steps
**Ready for Review**: Run `/review-task {task-number}`
**Suggested Next Task**: `{next-task-number} {next-task-title}`
```

## Project Conventions

Before implementing, the builder reads `.claude/config.json` and follows:

**Naming Conventions:**
- Classes/Types, Functions/Methods, Variables, Files/Directories

**Code Style:**
- Indentation, String quotes, Semicolons

**Architecture:**
- Layer structure, Patterns (CQRS, Repository, etc.), File placement

**Testing:**
- Testing framework, Coverage percentage, Test naming

**Documentation:**
- Code comments per config (XML docs, JSDoc, docstrings)

## Role & Responsibilities

**The Builder (via builder agent):**
- ✅ Implements specific tasks from phase files, nothing more
- ✅ Follows the blueprint - no architectural decisions
- ✅ Stays within scope - only touches specified files
- ✅ Writes tests as specified
- ✅ Updates checkboxes
- ✅ Reports completion with summary

**The Builder does NOT:**
- ❌ Make architectural decisions (Software Architect's job)
- ❌ Validate or review code (Manager's job)
- ❌ Modify files outside task scope
- ❌ Refactor existing code unless explicitly required
- ❌ Add features not mentioned in task
- ❌ Skip acceptance criteria

## Quality Checklist

Before reporting completion:
- [ ] Implemented all checkbox items
- [ ] Followed naming conventions from config
- [ ] Added appropriate error handling
- [ ] Included documentation (comments, docs)
- [ ] Used async patterns correctly
- [ ] Ran build command to verify compilation
- [ ] Ran tests (if applicable)
- [ ] Updated phase file checkboxes
- [ ] Stayed within specified file locations
- [ ] Did not make architectural decisions

## Error Handling

### Phase File Not Found
```
❌ Phase File Not Found

Phase file not found at: .claude/tasks/{service}/{phase}.md

Troubleshooting:
- Verify service/feature name is correct
- Check phase number is correct
- Ensure blueprints have been converted to tasks
- Try: /blueprint-tasks to generate task files
```

### Task Already Completed
```
❌ Task Already Completed

Task {task-number} appears to be already completed (all checkboxes marked).

Options:
- Re-implement it anyway (may override changes)
- Review it with /review-task {task-number}
- Choose a different task

Reply with your choice.
```

### Unclear Task Scope
```
❌ Unclear Task Scope

Task {task-number} needs clarification:
- {specific question about scope}

Please provide additional details or update the task in the phase file.
```

### Dependency on Uncompleted Task
```
❌ Dependency Not Complete

Task {task-number} depends on task {dependency-number} which is not yet complete.

Suggestion: Implement task {dependency-number} first, then return to {task-number}.
```

## Integration with Workflow

**Follows designs from:**
- **software-architect** agent - Architecture blueprints provide context

**Hands off to:**
- **manager** agent - Quality validation via `review-task` Skill

**Used in development cycle:**
```
1. /blueprint - Architect creates architecture
2. /blueprint-tasks - Convert to phase-based tasks
3. /implement-task - Builder implements task ← YOU ARE HERE
4. /review-task - Manager validates work
5. [If review fails, rerun /implement-task with fixes]
6. /commit - Create smart commit
7. [Repeat for next task]
8. /create-pr - Create pull request
```

## Edge Cases

**Multiple Phases:**
If service has multiple phases (phase1, phase2, phase3), ensure:
- Phase number in task reference is correct
- Phase file exists for that number
- Tasks are implemented in phase order

**Cross-Service Dependencies:**
If task requires changes in multiple services:
- Task should specify all file locations
- Builder will modify files across services if explicitly listed
- Ensure no circular dependencies

**Long-Running Tasks:**
If task is complex and takes significant time:
- Break down into subtasks via checkboxes
- Mark checkboxes as completed incrementally
- Provide progress updates to user

## Notes

- The Builder is focused and disciplined - implements exactly what's specified
- Defers architectural decisions to Software Architect
- Defers quality validation to Manager
- Stays within scope - resists scope creep
- Updates progress markers (checkboxes) religiously
- Provides detailed implementation reports for transparency
- Verifies work via build/test before reporting completion
- Works best when task sections are clear and specific
- References blueprint for architectural patterns but doesn't deviate from task spec
