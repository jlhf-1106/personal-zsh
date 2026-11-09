---
name: board-sync
description: >
  Keep the GitHub Projects board in sync while working a ticket: read its
  column and move it Ready -> In progress -> In review -> Done as work advances.
  Use whenever the user refers to a ticket, issue or card of the board: "#74",
  "ticket 59", "issue 61", "work on the stalled refresh ticket", "pick up the
  next Ready ticket", "start/finish/ship the ticket", "open the PR for #60",
  "is #62 done?". Trigger even if the user never says "board" or "move".
---

# Board sync

Board: the GitHub Projects v2 board linked to the current repo. The helper finds it from the issue, so no owner, project number or IDs are hardcoded; it works for any user or org the current `gh` login can access.

```bash
S=.claude/skills/board-sync/scripts/move.sh
$S <number>              # show current status
$S <number> <stage>      # move it
$S list [stage]          # tickets on the repo's board, optionally one column
```

`<stage>` is `start`, `review`, `done`, `ready` or `backlog`. The helper matches it to the board's own column names (e.g. `start` -> "In progress" or "Doing"), so boards with different names work. An exact column name also works. Exit 2 = not on a board. Exit 3 = no matching column (message lists the board's columns).

## Flow

The board is shared state the user watches, so moves must match real progress, not intent.

1. **Ticket named by number.** Run `move.sh N` to read it. If the user gave only a title or topic, find it with `$S list` and match the title; confirm with the user if more than one fits.
2. **Work starts** (user says start/work on/pick up, or you begin editing for the ticket): move with `start`. Ticket in `Backlog`? Ask first, since it was not triaged. Ticket already `In review` or `Done`? Tell the user, do not move it back unasked.
3. **PR opened for it**: move with `review`. Put `Closes #N` in the PR body so GitHub links it.
4. **PR merged / user says done**: move with `done`. Merged PRs with `Closes #N` often auto-move; run `move.sh N` to check before moving.
5. **Work paused or abandoned**: ask whether to return it with `ready`.

After each move, report the one line the script prints. No other commentary.

## Rules

- Never move a ticket you are not working on, and never skip ahead (no `Done` before the PR merges) unless the user says so.
- Moves are cheap and reversible, so do them without asking, except the `Backlog` and backward cases above.
- Issue not on the board (exit 2): say so, offer `gh project item-add <project-number> --owner <owner> --url <issue-url>`, do not add silently.
- If `gh` lacks the `project` scope, tell the user to run `! gh auth refresh -s project`.
