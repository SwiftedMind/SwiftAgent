# Commit Guidelines

Keep commits small, buildable, and easy to understand.

## Core expectations

- Make one logical change per commit and ensure the project still builds before and after the commit.
- Use Conventional Commits: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`. Add a scope when it clarifies the affected area. Mark breaking changes as `type(scope)!` and include a `BREAKING CHANGE:` line in the body.
- Write an imperative subject line no longer than 72 characters and without a trailing period. Add a short body that explains why the change is needed whenever it is not obvious from the diff.

## Grouping rules

- Keep dependent changes together: API changes with the call sites, renames with all mechanical updates, code with the assets or configuration it relies on, and build settings with the code they enable.
- Split out independent updates such as documentation-only edits, formatting cleanups, standalone tests, and dependency bumps (unless the code in the same commit requires them to compile).
- Follow project hygiene: respect `.gitignore`, do not commit secrets or large generated artifacts, and keep lockfiles in their own `chore(deps)` commit when possible.

## Simple workflow

1. Review the diff (`git status`, `git diff`) and decide which files belong in the same commit.
2. Pick the Conventional commit type and optional scope that best describe the change.
3. Stage only the files for that change and double-check the staged diff.
4. Commit with the chosen header, add context in the body if needed, and finish with references such as `Fixes #123` when relevant.
5. Verify the result with `git show --stat` and confirm a clean tree using `git status`.

## Examples

- `feat(payments): add card brand display`
- `fix(networking): retry 504 responses with jitter`
- `chore(deps): update Stripe SDK`

## Notes

- You don't need to build the project first; you can assume it builds successfully when I give you the task to commit.
