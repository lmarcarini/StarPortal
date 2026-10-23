# Project board sync

The workflow `.github/workflows/board-sync.yml` keeps the owner's GitHub Project board in step
with the cards. It is one way: labels move cards, the board never changes labels. Pull requests
are not on the board. Bible: [roadmap.md#the-board](bible/roadmap.md#the-board).

## What it does

It runs when an issue is opened, labeled, unlabeled, closed or reopened, and sets the card's
Status from the issue. The first row that matches wins. Status options are matched by name,
ignoring case and spaces, trying the names in the order shown.

| Issue state | Status option |
| --- | --- |
| closed | `Done` |
| label `needs-owner` | `Needs owner` |
| label `changes-requested` | `Changes requested` |
| label `in-review` | `In review`, `On Review`, `Review` |
| label `in-progress` | `In progress` |
| label `ready` | `Ready`, `Todo` |
| label `backlog`, or none of the above | `Backlog` |

- An issue with a milestone label (`M0`, `M0.5`, `M1`, ...) that is not on the project yet is
  added to it first. The size labels `M` and `S` do not count. An issue without a milestone
  label that is not on the project is left alone.
- If no Status option matches, the run logs a warning that lists the options it found and
  changes nothing.
- If the secret or a variable below is missing, the run ends successfully with a notice that
  names what to set. It never fails CI.

## One-time setup (owner)

1. Create a classic personal access token (GitHub: Settings, Developer settings,
   Personal access tokens, Tokens (classic)) with the scopes `repo` and `project`.
   Fine-grained tokens cannot reach projects owned by a user account, so they do not work here.
2. In the repository, open Settings, Secrets and variables, Actions. Add the token as the
   repository secret `PROJECT_TOKEN`.
3. On the same page, add two repository variables:
   - `PROJECT_OWNER` = `lmarcarini`
   - `PROJECT_NUMBER` = the number in the project URL (`github.com/users/lmarcarini/projects/<number>`).
4. Check that the project has a `Status` field with the columns from the table above.

The token is only passed to the GitHub CLI as `GH_TOKEN`; the script never prints it.

## Testing it by hand

Issue events only run the workflow from the default branch, so test after the workflow is
merged:

1. Open the repository's Actions tab, choose **board-sync**, then **Run workflow**.
2. Type the number of an issue and run it.
3. Open the run. Before the setup it ends green with a notice naming the missing secret or
   variables. After the setup the log shows `#<number> -> <Status>` and the card moves.
