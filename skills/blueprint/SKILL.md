---
name: blueprint
description: Create comprehensive architecture blueprints for new services or features with production-ready design and multi-phase implementation plans
allowed-tools: Read, Write, Bash, Grep, Glob
auto-discover:
  - "design"
  - "architecture"
  - "blueprint"
  - "new service"
  - "new feature"
  - "technical design"
---

# Blueprint Skill

## Purpose

Creates comprehensive architecture blueprints for new services or features following industry best practices. Generates production-ready designs with domain modeling, technical architecture, API specifications, and multi-phase implementation plans.

This Skill delegates the actual blueprint creation to the **software-architect** agent, which provides expert architectural guidance.

## Auto-Discovery Triggers

This Skill automatically activates when users mention:
- "I want to design a {service/feature}"
- "Create architecture for {description}"
- "Need blueprint for {description}"
- "Design a {technical concept}"
- "Blueprint for {new component}"

## Example Invocations

```
"Design a payment processing service with Stripe integration"
"Create blueprint for user notification system with email and push"
"I need architecture for a real-time analytics dashboard"
"Blueprint for order management system"
```

## Workflow

### 1. Read Project Configuration

**CRITICAL**: Before beginning, read `.claude/config.json` to understand:
- **Project type**: backend, frontend, fullstack, mobile
- **Tech stack**: dotnet, nodejs, python, go, java, react, nextjs, etc.
- **Architecture pattern**: clean-architecture, hexagonal, mvc, microservices, etc.
- **Naming conventions**: PascalCase, camelCase, snake_case
- **Testing framework**: What testing tools to use
- **Coverage goals**: Minimum test coverage target

**If `.claude/config.json` doesn't exist:**
- Ask the user to provide:
  - Project type
  - Tech stack
  - Architecture pattern
  - Key conventions

### 2. Study Existing Examples (Optional)

If `.claude/examples/` directory exists:
- Read example blueprints to understand structure and detail level
- Match the style and conventions of existing examples
- Note any project-specific patterns or requirements

### 3. Gather Requirements

Ask the user for:
- **Service/Feature Description**: What is being built?
- **Business Purpose**: What problem does it solve?
- **Integration Points**: What existing services/APIs will it integrate with?
- **Key Constraints**: Performance, security, compliance requirements

### 4. Delegate to Software Architect Agent

Invoke the **software-architect** agent to create the blueprint. The agent will generate a comprehensive design including:

**11+ Required Sections:**
1. **Frontmatter** - Project metadata, tech stack, purpose
2. **Domain Overview** (Backend) / **Component Overview** (Frontend)
3. **Data Model** - Entities, relationships, state shape
4. **Core Features & Use Cases** - User personas, commands, queries
5. **Technical Architecture** - Project structure, endpoints, caching
6. **API Design** - Specifications, auth, error handling
7. **Database Schema** (Backend) - Tables, indexes, migrations
8. **Implementation Phases** - 4-6 week breakdown with tasks
9. **Technical Considerations** - Security, performance, testing
10. **Dependencies & Integration** - External services, libraries
11. **Testing Strategy** - Unit, integration, E2E tests

### 5. Save Blueprint

**File Location**: `.claude/blueprints/{service-or-feature-name}-blueprint.md`

**Filename Convention**:
- Derive from service/feature description
- Use lowercase with hyphens
- Examples:
  - "payment processing service" → `payment-service-blueprint.md`
  - "user profile feature" → `user-profile-feature-blueprint.md`
  - "analytics dashboard" → `analytics-dashboard-blueprint.md`

**Create directory if needed**:
```bash
mkdir -p .claude/blueprints
```

### 6. Provide Summary

After saving the blueprint, provide:
- **Key architectural decisions** made
- **Integration points** with existing systems
- **Estimated complexity**: Simple, Moderate, or Complex
- **Recommended implementation order**: Which phases first
- **Critical dependencies**: What must be addressed before starting

## Blueprint Structure Details

### For Backend Services

**Domain Overview:**
- Bounded context and responsibilities
- Integration points (REST, GraphQL, message queues)
- Core business rules (8-15 key rules)

**Data Model:**
- Entities and aggregates
- Relationships and cardinality
- Value objects and enums
- Code examples in project language

**Technical Architecture:**
- Project structure following configured pattern
- API endpoints with request/response formats
- Database schema and indexes
- Caching strategy
- Event/message patterns

### For Frontend/Mobile

**Component Overview:**
- Feature scope and user flows
- State management approach
- API integration patterns

**Data Model:**
- Component hierarchy
- State shape (Redux, Context, etc.)
- Props interfaces/types
- Data flow patterns

**Technical Architecture:**
- Component structure
- Routing/navigation
- State management architecture
- API client integration
- Styling approach

## Implementation Phases

Blueprints include 4-6 week-long phases:
- **Phase 0**: Prerequisites (if any)
- **Phase 1**: Core foundation (Week 1)
- **Phase 2**: Key features (Week 2)
- **Phase 3**: Integration (Week 3)
- **Phase 4**: Polish and optimization (Week 4)
- Additional phases as needed

**Each phase:**
- Has 5-10 major tasks
- Is completable in ~1 week
- Builds upon previous phases
- Has clear deliverables

**MVP Completion Checklist** included with concrete deliverables.

## Code Examples

Blueprints provide concrete code examples in the project's language:

**Backend Entity Example:**
```csharp
// .NET example
public class Order : BaseEntity
{
    public string OrderNumber { get; private set; }
    public decimal TotalAmount { get; private set; }
    public OrderStatus Status { get; private set; }

    private readonly List<OrderItem> _items = new();
    public IReadOnlyCollection<OrderItem> Items => _items.AsReadOnly();

    public static Order Create(string customerId, List<OrderItem> items)
    {
        // Validation and creation logic
    }
}
```

**Frontend Component Example:**
```typescript
// React + TypeScript example
interface UserProfileProps {
    userId: string;
    onUpdate?: (user: User) => void;
}

export const UserProfile: React.FC<UserProfileProps> = ({ userId, onUpdate }) => {
    const [user, setUser] = useState<User | null>(null);
    const [isLoading, setIsLoading] = useState(true);

    // Component logic
};
```

## Technical Considerations Addressed

**All Projects:**
- Authentication & authorization patterns
- Error handling strategy
- Validation approach (where, what, how)
- Testing strategy and coverage goals
- Performance considerations
- Security concerns (OWASP top 10)

**Backend Specific:**
- Database connection pooling
- API versioning strategy
- Observability (logging, metrics, tracing)
- Deployment architecture
- Scalability patterns (horizontal scaling, load balancing)

**Frontend Specific:**
- Component reusability
- Performance optimization (code splitting, lazy loading)
- Accessibility (a11y) compliance
- SEO considerations (if applicable)
- Mobile responsiveness

## Validation Checklist

Before finalizing blueprint, ensure:
- [ ] Follows configured architecture pattern
- [ ] Uses correct naming conventions for tech stack
- [ ] Includes all 11+ required sections
- [ ] Provides concrete code examples
- [ ] Defines clear phases (4-6 weeks)
- [ ] Has measurable acceptance criteria
- [ ] Addresses security and performance
- [ ] Considers testing strategy
- [ ] Documents integration points
- [ ] Saves to `.claude/blueprints/` directory

## Integration with Workflow

**Downstream Skills:**
- `/blueprint-tasks` command - Converts blueprint into phase task files (`.claude/tasks/`)
- `implement-task` Skill - Builder references blueprint for architectural context
- `review-task` Skill - Manager validates implementation against blueprint

**Agent Delegation:**
- **software-architect** agent - Performs the actual blueprint creation
- This Skill orchestrates the workflow and handles file I/O

## Error Handling

### Missing Configuration

If `.claude/config.json` doesn't exist:
```
❌ Configuration file not found

.claude/config.json is required for blueprint creation.

Please provide:
- Project type (backend/frontend/fullstack/mobile)
- Tech stack (dotnet/nodejs/python/react/etc.)
- Architecture pattern (clean-architecture/mvc/hexagonal/etc.)
- Naming conventions
- Testing framework
```

### Invalid Blueprint Request

If user request is too vague:
```
❌ Insufficient detail for blueprint

Please provide more information:
- What service/feature are you building?
- What problem does it solve?
- What are the key use cases?
- What does it integrate with?
```

### File Write Errors

If unable to create `.claude/blueprints/` directory or save file:
```
❌ Failed to save blueprint

Error: {error message}

Troubleshooting:
- Check write permissions for .claude/ directory
- Verify disk space availability
- Try saving manually to: .claude/blueprints/{name}-blueprint.md
```

## Notes

- Blueprints are living documents - update as design evolves
- The software-architect agent provides expert architectural guidance
- Blueprints should be practical and implementable, not theoretical
- Focus on business value delivery while maintaining technical excellence
- Consider team size and timeline when estimating phases
- Include both happy path and edge case handling
- Address operational concerns (deployment, monitoring, debugging)
- Balance completeness with MVP scope

## Related Skills and Commands

**Commands:**
- `/blueprint-tasks` - Convert blueprint to phase task files
- `/commit` - Commit blueprint to version control
- `/create-pr` - Create PR with blueprint changes

**Skills:**
- `implement-task` - Implement tasks from phase files (references blueprint)
- `review-task` - Validate implementation (checks against blueprint)

**Agents:**
- **software-architect** - The expert agent that creates the blueprint
- **builder** - Will implement the blueprint in phases
- **manager** - Will validate implementation against blueprint
