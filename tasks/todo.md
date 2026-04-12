# PR #346 Review Resolution Plan

## Scope

- PR: [PR #346](https://github.com/gatanasi/server-hub/pull/346)
- Goal: Address all unresolved review threads holistically, then reply and resolve each thread.

## Tasks

- [ ] Harden test workflow trigger safety for self-hosted runner usage on pull_request events.
- [ ] Replace brittle Node runtime fallback logic in cleanup verification step.
- [ ] Preserve known_hosts semantics during post cleanup when the file pre-existed.
- [ ] Apply copy/wording polish fixes requested in review comments.
- [x] Harden test workflow trigger safety for self-hosted runner usage on pull_request events.
- [x] Replace brittle Node runtime fallback logic in cleanup verification step.
- [x] Preserve known_hosts semantics during post cleanup when the file pre-existed.
- [x] Apply copy/wording polish fixes requested in review comments.
- [x] Validate changed workflow and action scripts.
- [x] Commit and push branch updates.
- [x] Reply on each unresolved thread with resolution details.
- [x] Resolve all addressed review threads in PR.

## Review Notes

- Verified syntax: `node --check` for main.js, post.js, known-hosts-utils.js.
- Verified cleanup behavior in isolated HOME test scenarios:
  - known_hosts absent before setup -> post cleanup deletes action-created known_hosts.
  - known_hosts pre-existing but whitespace-only -> post cleanup preserves file.
  - known_hosts pre-existing with comment -> post cleanup preserves comment content.
- Pushed fix commit: `128e9b2` on branch `chore/harden-runner-vm`.
- Replied to all 8 previously unresolved review comments.
- Resolved all 8 previously unresolved review threads (remaining unresolved: 0).
