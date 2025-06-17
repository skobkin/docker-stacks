# New Stack Creation Guidelines

## 1. Directory Structure
- Each stack should have its own directory at the root level.
- Common subdirectories (as needed):
  - `config/` — for application configuration files.
  - `nginx/` — for Nginx reverse proxy configs.
  - `data/`, `db/`, `logs/`, `upload/`, etc. — for persistent or shared volumes.

## 2. Essential Files
- `docker-compose.yml` — The main Compose file for the stack.
- `.env.dist` — Template for environment variables. Should include all required variables with example/default values.
- `README.md` — Additional documentation for the stack. Created **only** if root `README.md` doesn't explain something that's
necessary to run the stack:
  - Setup instructions (referencing the root README for common steps).
  - Any stack-specific notes or caveats.
  - Links to additional docs in `_docs` if needed.

## 3. docker-compose.yml Best Practices
- Do not use schema version as it's deprecated.
- Reference environment variables via `env_file: .env` and/or `environment:`.
- Use `${VAR:-default}` syntax for environment variables to provide defaults.
- Use `restart: unless-stopped` for most services.
- Set up logging with:
  ```yaml
  logging:
    driver: "json-file"
    options:
      max-size: "${LOG_MAX_SIZE:-5m}"
      max-file: "${LOG_MAX_FILE:-5}"
  ```
- Use named volumes for persistent data.
- Use `depends_on` for service dependencies.
- Expose only necessary ports, preferably bound to `127.0.0.1` unless external access is required.
- Add comments with links to official images or documentation where helpful.

## 4. `.env.dist` Best Practices
- Include all variables referenced in `docker-compose.yml`.
- Provide example values and comments for each variable.
- Provide links to useful documentation if it exists
- Never include secrets or production credentials.

## 5. `README.md` Best Practices
- Create **ONLY** if basic `README.md` doens't describe everything that's needed. For example if external network is required.
- Briefly describe the stack and its purpose.
- Reference the root `README.md` for general setup.
- Document any special configuration, required networks, or caveats.
- Link to official documentation or image sources.

## 6. Nginx/Config Files
- Place Nginx configs in an `nginx/` subdirectory.
- Place application configs in a `config/` subdirectory.
- Provide `.dist` versions for template configs if user customization is expected and add user-modified versions to the `.gitignore` file located in the same directory (not root `.gitignore`).

## 7. Version Control
- Do not commit `.env` or other files containing secrets.
- Commit `.env.dist` and config templates only.

---

# Step-by-Step Checklist for Creating a New Stack

1. **Create a new directory** for the stack at the root level.
2. **Add a `docker-compose.yml`** file:
   - Follow the best practices above.
   - Reference environment variables via `.env`.
3. **Create a `.env.dist`** file:
   - List all required variables with example values.
   - Add comments for clarity.
4. **Add a `README.md` only if it's needed**:
   - Describe the stack, setup, and any special notes.
5. **Add config directories/files** as needed:
   - `config/`, `nginx/`, `data/`, etc.
   - Provide `.dist` templates for configs if needed.
6. **Update the root `README.md`**:
   - Add the new stack to the table with status, image, description, and links.
87 **Commit only safe files**:
   - Exclude `.env` and any files with secrets.
   - Include `.env.dist`, config templates, and documentation.
