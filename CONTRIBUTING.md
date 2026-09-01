# Contributing

Contributions are welcome when they keep the project reproducible, reviewable,
and safe to deploy on a real desktop. For substantial behavior or architecture
changes, open an issue first so scope and compatibility can be agreed before a
large patch is prepared.

## Development workflow

1. Branch from the current `main` branch and keep each change focused.
2. Do not run tests against a live session when they would reload Hyprland,
   switch workspaces, modify outputs, install system files, or expose private
   desktop state.
3. Run the stable repository checks below from the project root:

   ```bash
   git ls-files -z -- '*.sh' ':!config/hypr/hyprland/scripts/fuzzel-emoji.sh' | xargs -0 -r -n1 bash -n
   python3 -m compileall -q bin scripts shell tests
   PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -v
   git diff --check
   ```

4. When the documented native dependencies are available, also run
   `bash scripts/verify.sh` and record any environment-dependent skips or
   failures in the pull request.

## Privacy and safety

Never commit credentials, API tokens, account data, coordinates, connector
identifiers tied to a private setup, notifications, chats, session state, or
unredacted captures. Use the empty files under `private.example/` for examples.
Inspect both the staged diff and any newly added binary metadata; `.gitignore`
is a safety net, not a substitute for review.

Install and uninstall scripts must remain dry-run by default. Changes affecting
PAM, locking, user services, network integrations, or commands derived from
external input need explicit threat analysis and focused tests.

## Licensing and provenance

Original contributions are submitted under `GPL-3.0-only`. Do not copy code,
artwork, fonts, screenshots, or generated assets from a source whose license and
redistribution terms have not been confirmed. Preserve source-file notices and,
for every new third-party component, update the repository's license text and
component-to-file notice with its upstream URL, revision, copyright, license,
and modification status.

By opening a pull request, you confirm that you have the right to submit the
contribution under the stated terms.

## Pull request checklist

- Explain the user-visible effect and compatibility impact.
- List the checks run and their results.
- Include focused regression tests for behavior changes.
- Call out security, privacy, migration, and rollback considerations.
- Keep generated files reproducible from committed sources.
