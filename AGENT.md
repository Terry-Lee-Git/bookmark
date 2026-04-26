# Project Standards & Superpowers

## Core Architecture & Platform
- **Common Library:** All shared logic resides in `./lib/common/`. 
- **Discovery Rule:** Before implementing any feature, read `./lib/common/MANIFEST.md`. NEVER recreate logic found in the library.
- **Service Scaffolding:** New services MUST be created using the `create-service` skill and include `build.sh`, `.vm_options`, and a `pvt` version file.
- **Environment:** Use H2 in-memory database for local development and testing.

## Coding Standards (Java)
- **Naming:** Follow Google Java Naming Conventions strictly.
- **Style:** Prioritize clean, readable code over clever optimizations.
- **Async Pattern:** Prefer Vert.x fluent async style. Use `Future.compose` for chaining.
- **Promises:** Avoid using `Promise` directly unless absolutely necessary for low-level interop.
- **APIs:** Design strictly RESTful APIs with proper resource naming and HTTP methods.

## Quality & Logging
- **Testing:** Prefer Integration Testing for critical business flows over shallow unit tests.
- **Auth in Tests:** For local test profiles, disable authentication (e.g., `security.enabled=false`).
- **Logging:** Include meaningful, traceable logs. Ensure every log entry can be linked to a request/correlation ID.

## Workflow Rules
- Use the `brainstorming` skill before starting any new feature.
- Run `/review` before completing a task to ensure compliance with the Google Java style and Vert.x async patterns.
