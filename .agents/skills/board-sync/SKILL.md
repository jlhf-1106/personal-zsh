---
name: board-sync
description: >
  Keep the GitHub Projects board in sync while working a ticket: read its
  column and move it Ready -> In progress -> In review -> Done as work advances.
  Use whenever the user refers to a ticket, issue or card of the board: "#74",
  "ticket 59", "issue 61", "work on the stalled refresh ticket", "pick up the
  next Ready ticket", "start/finish/ship the ticket", "open the PR for #60",
  "is #62 done?". Also covers ticket priority (GitHub's native Priority issue
  field): "what's most urgent?", "next ticket", "make #61 high priority",
  "file a bug". And type labels on issues/PRs ("label it", "tag #61", any new
  issue or PR). Trigger even if the user never says "board" or "move".
---

# Board sync

Board: the GitHub Projects v2 board linked to the current repo. The helper finds it from the issue, so no owner, project number or IDs are hardcoded; it works for any user or org the current `gh` login can access.

```bash
S=.claude/skills/board-sync/scripts/move.sh
$S <number>              # show current status
$S <number> <stage>      # move it
$S list [stage]          # tickets on the repo's board, optionally one column

P=.claude/skills/board-sync/scripts/priority.sh
$P <number>              # show current priority
$P <number> <level>      # set it: urgent | high | medium | low | none
$P list [stage]          # board tickets sorted Urgent > High > Medium > Low > none
```

`<stage>` is `start`, `review`, `done`, `ready` or `backlog`. The helper matches it to the board's own column names (e.g. `start` -> "In progress" or "Doing"), so boards with different names work. An exact column name also works. Exit 2 = not on a board. Exit 3 = no matching column (message lists the board's columns).

Priority is the owner's native **Priority** issue field (Urgent, High, Medium, Low), set on the issue itself: not a label and not a board column. `priority.sh` finds the field and its options by name, so no IDs are hardcoded. Exit 2 = the owner has no Priority issue field (user-owned repos). Exit 3 = no matching level (message lists the options).

## Flow

The board is shared state the user watches, so moves must match real progress, not intent.

1. **Ticket named by number.** Run `move.sh N` and `priority.sh N` to read it. If the user gave only a title or topic, find it with `$S list` and match the title; confirm with the user if more than one fits.
2. **Work starts** (user says start/work on/pick up, or you begin editing for the ticket): move with `start`. Ticket in `Backlog`? Ask first, since it was not triaged. Ticket already `In review` or `Done`? Tell the user, do not move it back unasked.
3. **PR opened for it**: move with `review`. Put `Closes #N` in the PR body so GitHub links it.
4. **PR merged / user says done**: move with `done`. Merged PRs with `Closes #N` often auto-move; run `move.sh N` to check before moving.
5. **Work paused or abandoned**: ask whether to return it with `ready`.

After each move, report the one line the script prints. No other commentary.

## Priority

- **Picking work** ("next ticket", "what should I do?"): run `$P list ready` and take the top one (highest priority, then lowest number). Unset priority goes last. Never pick by board order or by `priority:*` labels.
- **Several tickets at once**: work and open the PRs in priority order, Urgent first.
- **Starting a lower-priority ticket** while a higher one is still `Ready`: do it if the user named it, but say which higher ones are waiting, in one line.
- **New issue you file**: set its priority in the same step (`$P N <level>`), using the user's level if they gave one; otherwise propose one with a one-line reason and set it once they agree. Never use priority labels.
- **Changing an existing priority**: only when the user asks. If the work shows it is wrong (e.g. a "Low" bug blocks a release), say so and suggest the new level; do not change it yourself.
- **Reporting**: when you list or mention tickets, show the priority next to the status (`#23 [High] [In review] ...`).
- After each change, report the one line the script prints.

## Type labels

Every issue and PR gets one **type label** for the kind of change requested (what the ticket asks for, not every file the fix touches).

| Change requested | Commit prefix | Label |
| --- | --- | --- |
| Something is broken | `fix:` | `bug` |
| New feature or capability | `feat:` | `enhancement` |
| Only docs (README, AGENTS, comments) | `docs:` | `documentation` |
| Faster startup or install | `perf:` | `performance` |
| Restructure, same behaviour | `refactor:` | `refactor` |
| Only tests | `test:` | `tests` |
| CI workflows | `ci:` | `ci` |
| Tooling, deps, cleanup, agent skills | `chore:` | `chore` |

- **Reuse first**: run `gh label list --limit 100` and use the label above if it exists, or an existing one that clearly means the same (e.g. `perf` for `performance`). Do not create near-duplicates.
- **Create only when none fits**: `gh label create <name> --color <hex> --description "<English, one line>"`. Lowercase, one word. Colors: `performance` `1D76DB`, `refactor` `5319E7`, `tests` `0E8A16`, `ci` `BFD4F2`, `chore` `EDEDED`; any other new type gets a color unused by existing labels. Never `--force` (it rewrites an existing label). Tell the user in one line when you create one.
- **Second label**: add `documentation` next to the type only when the request itself asks for docs (e.g. "document that the font must be installed on Windows"); updating README/AGENTS as part of every change does not count.
- **Issue first, PR mirrors it**: label the issue when you file or triage it (`gh issue edit N --add-label <label>`); the PR that fixes it gets the same labels (`gh pr create --label ...` or `gh pr edit N --add-label ...`), and its commit prefix matches the type.
- **Wrong label on an existing ticket**: say so and suggest the fix; change it only when the user asks.
- Labels are only for type. Never use `priority:*` labels: priority is the Priority field above.

## Rules

- Never move a ticket you are not working on, and never skip ahead (no `Done` before the PR merges) unless the user says so.
- Moves are cheap and reversible, so do them without asking, except the `Backlog` and backward cases above.
- Issue not on the board (exit 2): say so, offer `gh project item-add <project-number> --owner <owner> --url <issue-url>`, do not add silently.
- If `gh` lacks the `project` scope, tell the user to run `! gh auth refresh -s project`.
