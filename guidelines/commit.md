# Commit Guidelines

1. Review the workspace state:
   - Run `git status` to see modified files.
   - Run `git diff` (optionally with specific paths) and decide which files belong in this commit. Keep the change focused and buildable.

2. Apply the project commit rules while preparing the message:
   - Use a Conventional Commit type (`feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`). Add a scope when it clarifies the area, and mark breaking changes as `type(scope)!` with a `BREAKING CHANGE:` line in the body.
   - Write an imperative subject no longer than 72 characters and omit the trailing period.
   - Include a short body explaining why the change is needed whenever it is not obvious from the diff.
   - **SKIP building or formatting**; always assume those checks have already been handled.

3. Stage and commit the files:
   - Stage only the files for this logical change with `git add`.
   - Double-check the staged diff using `git diff --staged`.
   - Run `git commit` with the prepared header and optional body (e.g. `git commit -m "type(scope): concise imperative subject"`). Add references such as `Fixes #123` when relevant.

4. Verify the result:
   - Inspect the commit summary with `git show --stat`.
   - Confirm the state using `git status`.

5. If `git status` still reports changes, repeat from Step 1 and create additional commits until the working directory is clean, amending when something needs correction.

## General Notes
- Do this with minimal exploration. Stop as soon as actionable context is sufficient. The commits do not have to contain every single detail.
