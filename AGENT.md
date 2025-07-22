# Séance

Séance is a Nim-based library and CLI utility. The core functionality lives in the `src/` folder.

## Build & Commands

- Install Nim: `curl https://nim-lang.org/choosenim/init.sh -sSf | sh -s -- -y`
- Add it to your path: `export PATH=/home/jules/.nimble/bin:$PATH`
- Install dependencies: `nimble install -d --accept`
- Typecheck and lint: `nim check src/`
- Reformat: `nimpretty`
- Run tests: `nimble test`
- Build for production: `nimble build`

## Code Style

- Follow the official Nim style guide
- Two spaces for indentation in .nim files
- Use descriptive variable/function names
- Prefer functional programming patterns where possible
- Use docstrings for documenting public APIs, not `#` comments
- Don't refactor code needlessly
- 100 character line limit
- Import local modules first, then standard library, then third-party libraries. Separate each with a blank line.
- In CamelCase names, use "URL" (not "Url"), "API" (not "Api"), "ID" (not "Id")
- Do not suppress errors unless instructed to

## Testing

- Use Nim's built-in `unittest` module
- Test one thing per test
- Use `check VALUE == expected` instead of storing in variables
- Omit "should" from test names (e.g., `test "validates input":`)
- Test files: `*.nim` in `tests/` directory
- Mock external dependencies appropriately
- Do not disable tests to make them pass

## Security

- Use appropriate data types that limit exposure of sensitive information
- Never commit secrets or API keys to repository
- Use environment variables for sensitive data
- Validate all user inputs
- Use HTTPS in production (if applicable)
- Regular dependency updates
- Follow principle of least privilege

## Git Workflow

- ALWAYS run `nim check src/` before committing
- Fix linting errors with `nimpretty` before committing
- Run `nimble build` to verify typecheck passes
- NEVER use `git push --force` on the main branch
- Use `git push --force-with-lease` for feature branches if needed
- Always verify the current branch before force operations

## Configuration

When adding new configuration options, update all relevant places:
1. Environment variables in `.env.example` (if used)
2. Configuration schemas in `src/config/` (if used)
3. Documentation in README.md

All configuration keys use consistent naming and MUST be documented.