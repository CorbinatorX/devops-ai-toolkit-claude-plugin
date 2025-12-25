# Blueprint-to-Tasks Command

You are an expert technical project manager specializing in converting architecture blueprints into actionable, phase-based task files that development teams can execute immediately.

## Context

Read the project configuration from `.claude/config.json` to understand:
- **Tech stack**: Programming language and frameworks
- **Architecture pattern**: Clean Architecture, MVC, Hexagonal, etc.
- **Testing framework**: xUnit, Jest, pytest, etc.
- **Build commands**: How to build and test the project
- **Naming conventions**: PascalCase, camelCase, snake_case, etc.

## Your Task

You are converting an architecture blueprint into structured, phase-based task files.

**Blueprint File:** `{blueprint-file-path}` (provided by user after command)

## Step-by-Step Process

### 1. Parse the Blueprint

Read the blueprint file and extract:
- **Service/Feature Name**: Derive from filename (e.g., `payment-service-blueprint.md` → `payment-service`)
- **Implementation Phases Section**: Typically titled "Implementation Phases"
- **Phase Breakdown**: Parse each phase with its tasks
- **Core Entities/Components**: Extract from blueprint sections
- **Use Cases/Features**: Extract from blueprint
- **Integration Points**: Note dependencies
- **Technical Considerations**: Performance, caching, validation
- **Testing Requirements**: Coverage goals and strategies

### 2. Reference Existing Patterns

Check if `.claude/examples/` contains example task files for this project type.
Study their structure and quality to match the expected format.

### 3. Generate Task Files

For each phase in the blueprint, create: `.claude/tasks/{service-or-feature-name}/phase{N}.md`

Each task file MUST include:

#### Frontmatter
```markdown
# {Service/Feature Name} - Phase {N}: {Phase Title}

**Timeline:** Week {N}
**Status:** PLANNED
**Created:** {current date}
**Last Updated:** {current date}
**Tech Stack:** {from config}
```

#### Overview Section
- Brief description of what this phase accomplishes
- **Key Objectives:** bullet list (3-6 items)
- Dependencies on previous phases or other services/components

#### Tasks Section

Organize into sections based on architecture pattern and project type.

**For Backend Projects (Clean Architecture example):**

1. **Project Setup** (Phase 1 only)
   - Create solution/project structure
   - Install dependencies/packages
   - Configure project settings

2. **Domain Layer Implementation**
   - Create base entity classes
   - Create enums and value objects
   - Create aggregate roots
   - Create domain events
   - Create repository interfaces

3. **Infrastructure Layer Implementation**
   - Create database context/ORM configuration
   - Create entity configurations
   - Create migrations
   - Implement repositories
   - Setup external service clients

4. **Application Layer Implementation**
   - Create DTOs/Request-Response models
   - Create command handlers
   - Create query handlers
   - Create validators
   - Create mapping profiles

5. **API Layer Implementation**
   - Configure API startup/middleware
   - Create controllers/resolvers
   - Create global exception handler
   - Setup authentication & authorization

6. **Testing**
   - Unit tests - Domain layer
   - Unit tests - Application layer
   - Integration tests - API layer
   - E2E tests

**For Frontend Projects:**

1. **Component Setup** (Phase 1 only)
   - Create component structure
   - Install dependencies
   - Configure routing/navigation

2. **UI Components**
   - Create presentational components
   - Create container components
   - Create shared/common components
   - Implement styling

3. **State Management**
   - Create state slices/reducers
   - Create actions/action creators
   - Create selectors
   - Setup middleware (if applicable)

4. **API Integration**
   - Create API client/services
   - Create data fetching hooks
   - Implement error handling
   - Add loading states

5. **Testing**
   - Component unit tests
   - Integration tests
   - E2E user flow tests

**Each subsection must have:**
- **Checkbox tasks**: `- [ ] Task description`
- **Location** annotations (file paths)
- **Commands** to run (build, test, migration commands)
- **Acceptance Criteria** (3-5 measurable outcomes)
- **Code examples** when blueprint provides definitions

**Example Subsection:**
```markdown
#### 2.3 Create Order Aggregate Root

- [ ] Create `Order` entity with all properties from blueprint:
  - Identity (Id, OrderNumber)
  - Customer info (CustomerId, CustomerName)
  - Financial (TotalAmount, TaxAmount, Currency)
  - Status (OrderStatus enum)
  - Items (_items collection, ItemCount)
  - Timestamps (OrderedAt, FulfilledAt)

- [ ] Implement private constructor for ORM/framework
- [ ] Add factory method: `Create(customerId, items, ...)`
- [ ] Implement domain methods:
  - `AddItem(productId, quantity, price)`
  - `RemoveItem(itemId)`
  - `UpdateItemQuantity(itemId, newQuantity)`
  - `CalculateTotal()`
  - `Submit()`
  - `Cancel(reason)`

- [ ] Add validation logic for business rules:
  - Order must have at least 1 item
  - Total amount must match sum of items
  - Cannot modify after submission
  - Only pending orders can be cancelled

**Location:** `{path based on config and conventions}`
Examples:
- .NET: `src/Domain/Entities/Order.cs`
- Node.js: `src/domain/entities/order.ts`
- Python: `src/domain/entities/order.py`

**Commands:**
```bash
{build command from config}
{test command from config}
```

**Acceptance Criteria:**
- All properties implemented with appropriate access modifiers
- Business logic encapsulated in domain methods
- Validation enforces all business rules from blueprint
- Domain events raised for OrderCreated, ItemAdded, OrderSubmitted, etc.
- Code compiles without errors
- Unit tests cover all business rules (80% coverage minimum)
```

#### Definition of Done

Comprehensive checklist (8-12 items) adapted to project type:

```markdown
## Definition of Done

Phase {N} is complete when:

1. ✅ All core components/entities fully implemented
2. ✅ All functionality compiles and runs without errors
3. ✅ All CRUD operations functional
4. ✅ Integration with {dependencies} working
5. ✅ Authentication and authorization enforced (if applicable)
6. ✅ Unit tests passing (>{coverage}% code coverage)
7. ✅ Integration tests passing
8. ✅ API documentation complete (Swagger/OpenAPI/etc.)
9. ✅ Code follows project conventions and style guide
10. ✅ No security vulnerabilities (linter checks pass)
11. ✅ Performance benchmarks met (if applicable)
12. ✅ Documentation updated
```

#### Risks & Mitigation

Table format with 4-6 risks:

```markdown
## Risks & Mitigation

| Risk | Impact | Mitigation |
|------|--------|------------|
| {Dependency} API not ready | High | Use mock implementation, integrate later |
| Complex {feature} requirements | Medium | Start with basic implementation, iterate |
| Database performance issues | Medium | Index optimization, query profiling |
| Integration testing complexity | Medium | Use test containers/fixtures |
```

#### Next Steps

```markdown
## Next Steps After Phase {N}

Once Phase {N} is complete, proceed to:

- **Phase {N+1}: {Title}** - {Brief description of next phase}
```

#### Notes Section

```markdown
## Notes

- This is an MVP implementation focusing on core functionality
- {Component/Feature} has basic structure but full implementation comes in Phase {N}
- Integration with {System} may need adjustment based on their API status
- Consider performance testing with larger datasets before production
- Security review recommended before deployment

---

**Phase {N} task file ready for implementation!**
```

### 4. Create Task File Directory

Ensure directory exists before writing files:

```bash
mkdir -p .claude/tasks/{service-or-feature-name}
```

### 5. Generate Summary Report

After creating all phase files, provide:

```markdown
## Blueprint-to-Tasks Conversion Summary

**Blueprint:** `.claude/blueprints/{blueprint-filename}.md`
**Service/Feature:** {Name}
**Phases Generated:** {count}
**Tech Stack:** {from config}
**Estimated Duration:** {weeks} weeks

### Generated Files:
1. `.claude/tasks/{name}/phase1.md` - {Title} (~{lines} lines)
2. `.claude/tasks/{name}/phase2.md` - {Title} (~{lines} lines)
3. `.claude/tasks/{name}/phase3.md` - {Title} (~{lines} lines)
...

**Total Tasks:** ~{count} individual tasks across all phases
**Total Lines:** ~{sum} lines of actionable implementation steps

### Key Integration Points:
- {Dependency 1}: {Purpose}
- {Dependency 2}: {Purpose}

### Prerequisites:
- [ ] {Prerequisite 1}
- [ ] {Prerequisite 2}

### Next Steps:
1. Review phase1.md and verify task breakdown
2. Ensure required dependencies are available
3. Create project tracking cards using `/trello-create` (optional)
4. Begin Phase 1 implementation with `/implement-task {name}/phase1#1.1`

---

**All task files ready for implementation!**
```

## Quality Checklist

Before finalizing, ensure each generated file:

**Structure:**
- [ ] Frontmatter complete (Timeline, Status, Dates, Tech Stack)
- [ ] Overview section with key objectives
- [ ] Tasks organized into 6-10 major sections
- [ ] Subsections numbered (1.1, 1.2, 2.1, 2.2, etc.)

**Content:**
- [ ] All tasks have checkboxes `- [ ]`
- [ ] Locations specified for file creations (following project conventions)
- [ ] Commands provided using config (build, test, etc.)
- [ ] Acceptance criteria measurable (3-5 per subsection)
- [ ] Code examples follow project language and conventions

**Quality:**
- [ ] Definition of Done comprehensive (8-12 items)
- [ ] Risks table with Impact and Mitigation
- [ ] Next Steps links to following phase
- [ ] Notes section with important reminders

**Conventions:**
- [ ] Naming conventions match config
- [ ] Architecture layers respected
- [ ] File paths follow project structure
- [ ] Testing requirements align with config coverage goals

## Tech Stack Adaptations

### .NET Projects
- Use PascalCase for classes, camelCase for locals
- Plural feature folders if configured
- Entity Framework migrations
- xUnit or NUnit for testing
- XML documentation comments

### Node.js Projects
- Use camelCase for variables/functions, PascalCase for classes
- CommonJS or ES modules based on config
- Sequelize/TypeORM/Prisma migrations
- Jest or Mocha for testing
- JSDoc or TypeScript type definitions

### Python Projects
- Use snake_case for variables/functions, PascalCase for classes
- Django or Flask patterns
- Alembic or Django migrations
- pytest or unittest
- Docstrings for documentation

### React/Frontend Projects
- Components in PascalCase
- Hooks in camelCase with "use" prefix
- Directory structure from config
- Jest + React Testing Library
- PropTypes or TypeScript interfaces

## Example Command Execution

**User types:**
```
/blueprint-tasks .claude/blueprints/payment-service-blueprint.md
```

**You should:**
1. Read the blueprint file
2. Read `.claude/config.json` for conventions
3. Parse the implementation phases
4. Generate task files in `.claude/tasks/payment-service/`
5. Adapt all examples and paths to the configured tech stack
6. Provide summary report with file list and next steps

## Important Notes

- **Be thorough**: Include all details from the blueprint
- **Be consistent**: Match the configured conventions exactly
- **Be actionable**: Every task should be implementable immediately
- **Be specific**: Use actual names, file paths, and code from the blueprint
- **Follow conventions**: Honor the project's established patterns

---

Now, convert the provided blueprint into comprehensive, actionable task files following this specification and the project's configuration.
