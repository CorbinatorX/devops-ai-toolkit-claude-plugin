# Claude Code Configuration

This directory contains configuration files that drive the AI agents and workflows in this plugin.

## config.json

The `config.json` file defines your project's architecture, conventions, and patterns. It's used by:

- **Software Architect Agent** (`/blueprint`) - Generates architecture blueprints aligned with your tech stack
- **Pickup Skills** (`/pickup-bug`, `/pickup-feature`) - Understands your project structure for implementation
- **Implementation Agent** - Follows your coding conventions and patterns
- **Review Agent** - Validates code against your standards

### Setup

1. Copy the example config:
   ```bash
   cp .claude/config.example.json .claude/config.json
   ```

2. Customize for your project:
   - Update `project.name`, `project.description`
   - Define your `architecture.components` (paths and purposes)
   - Set your `conventions` (naming, indentation, etc.)
   - Specify `frameworks` and versions
   - Configure `testing` commands
   - Define `infrastructure` layers

3. Add to `.gitignore` if it contains sensitive info, or commit it for team consistency

### Key Sections

#### `project`
Basic project metadata (name, type, tech stack, description)

#### `architecture`
- **pattern**: Architecture pattern (clean-architecture, hexagonal, layered, etc.)
- **components**: Map of component paths and purposes
- **layers**: Ordered list of architectural layers
- **featureOrganization**: How features are organized (by-feature, by-layer)

#### `conventions`
- **naming**: Naming conventions per language
- **indentation**: Spaces/tabs per language
- **maxLineLength**: Line length limits
- **typeHints**: Whether to use type hints
- **strictMode**: Strict type checking

#### `patterns`
- **api**: API layer patterns (routers, controllers, dependency injection)
- **application**: Business logic patterns (repositories, services, use cases)
- **ui**: Frontend patterns (hooks, state management, API client)

#### `frameworks`
Framework versions and tools per component (api, application, ui, infrastructure)

#### `testing`
- **framework**: Test framework per component
- **coverage**: Minimum coverage percentage
- **commands**: Commands to run tests, linting, type checking, formatting

#### `database`
Database configuration (type, migrations, commands)

#### `infrastructure`
IaC configuration (provider, tool, layers, commands)

#### `git`
Git workflow settings (PR templates, conventional commits, branch naming)

#### `documentation`
Documentation standards (docstrings, JSDoc, Swagger, blueprint paths)

#### `security`
Security patterns (auth, secrets management, RBAC)

#### `deployment`
Deployment configuration (environments, CI/CD, containerization)

## Usage in Skills

### Blueprint Skill
```bash
/blueprint
```
Reads `.claude/config.json` to generate architecture blueprints that align with your tech stack and patterns.

### Pickup Skills
```bash
/pickup-bug
/pickup-feature
```
Use the config to understand where to place new code and what patterns to follow.

### Implementation Agent
Follows your conventions and patterns when implementing tasks from blueprint phases.

### Review Agent
Validates implementations against your architecture and coding standards.

## Example: FastAPI + React Project

See `config.example.json` for a complete example of a FastAPI backend + React frontend project with:
- Clean architecture pattern
- Feature-based organization
- FastAPI + SQLAlchemy in backend
- React + TypeScript + Vite in frontend
- Azure infrastructure with Terraform
- Comprehensive testing setup

## Customizing for Your Stack

### Backend-Only (FastAPI)
Remove the `ui` component and adjust `architecture.layers` to exclude UI.

### Frontend-Only (React)
Remove `api` and `application` components, keep only `ui`.

### Microservices
Add multiple `components` entries for each service:
```json
{
  "architecture": {
    "components": {
      "auth-service": {
        "path": "services/auth/",
        "type": "fastapi",
        "purpose": "Authentication and authorization service"
      },
      "order-service": {
        "path": "services/orders/",
        "type": "fastapi",
        "purpose": "Order management service"
      }
    }
  }
}
```

### Different Tech Stack (.NET)
Update `frameworks` and `conventions`:
```json
{
  "frameworks": {
    "api": {
      "framework": ".NET",
      "version": "8.0",
      "orm": "Entity Framework Core"
    }
  },
  "conventions": {
    "naming": {
      "csharp": {
        "classes": "PascalCase",
        "methods": "PascalCase",
        "variables": "camelCase",
        "constants": "PascalCase"
      }
    }
  }
}
```

## Tips

1. **Keep it accurate**: The architect agent trusts this config - incorrect paths or patterns will lead to wrong blueprints
2. **Version control**: Commit `config.json` so the whole team uses the same architecture
3. **Update regularly**: When adding new frameworks or changing patterns, update the config
4. **Document anti-patterns**: Use the `antiPatterns` arrays to prevent common mistakes
5. **Link to CLAUDE.md**: Reference your project's `CLAUDE.md` in the `documentation.projectDocs` field

## Related Files

- `CLAUDE.md` - Project-specific guidance for Claude Code (in your project root)
- `blueprints/` - Generated architecture blueprints
- `tasks/` - Phase-based task files generated from blueprints
