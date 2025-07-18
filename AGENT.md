# Séance

Séance is a Nim-based library and CLI utility. The core functionality lives in the `src/` folder.

## Build & Commands

- Install Nim: `grabnim` (see Installation below)
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

## Installation

Use GrabNim to install nim and nimble, paying attention to its output for instructions on setting the $PATH:

```bash
wget -q0 - https://codeberg.org/janAkali/grabnim/raw/branch/master/misc/install.sh | sh 
```

It might be something like this:

```bash
export PATH="$HOME/.local/share/grabnim/current/bin:$PATH"
export PATH="$HOME/.nimble/bin:$PATH"
```

### GrabNim Usage

- `grabnim`                     Install and switch to latest stable version
- `grabnim <version>`           Install and switch to specific version
- `grabnim compile <ver>`       Clone Nim repo, compile, install and switch
- `grabnim upd|update <ver>`    Force update installed compiler ('devel'/'2.2.x')
- `grabnim del|delete <ver>`    Delete local version of compiler
- `grabnim fetch`               List remote available versions
- `grabnim list`                List local installed versions
- `grabnim ver|version`         Print grabnim version
- `grabnim help`                Display this help message

#### Examples

- `grabnim 2.2.4`             Install Nim v2.2.4 from official website
- `grabnim devel`             Install Nightly Nim devel from github
- `grabnim 2.2.x`             Install Nightly Nim latest-2-2 from github
- `grabnim compile devel`     Clone Nim repo and build master branch
- `grabnim compile 2.0.8`     Clone repo, switch to 'v2.0.8' tag and build
- `grabnim update devel`      Reset installed repo, pull and build
- `grabnim update 2.2.x`      Delete and reinstall latest-2-2 from github

### Paths Used by GrabNim

- Cache Directory: `$XDG_CACHE_HOME/grabnim-cache` or `~/.cache/grabnim-cache` if XDG_CACHE_HOME is not set
- Grabnim Directory: `$XDG_DATA_HOME/grabnim` or `~/.local/share/grabnim` if XDG_DATA_HOME is not set

Each version lives in its own subfolder (e.g., nim-2.0.0, nim-devel).