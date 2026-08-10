---
title: 'Goals, gates, and loops'
description: 'A method for building artifacts that maintain themselves, taught through one running example: the release line on this homepage, the gate that grades it, and the four defects the first drill caught.'
category: 'Production'
weight: 26
---

Every project accumulates facts that a human has to keep true. A version number in a README. A supported-models table. A homepage section listing recent releases. Nobody plans to let these rot. They rot anyway, because nothing in the system notices when they stop matching reality.

This guide describes the method we use instead, and then walks one real example end to end. Every file, issue, pull request, and workflow run linked here is public.

## Why hand-maintained artifacts rot

The aixgo.dev homepage used to carry six hand-written milestone cards. In August 2026 they still stopped at v0.5.0, and the card labelled "Current Release" described v0.6.0. The framework had shipped v0.7.4 back on 2 May.

Updating the cards took ten minutes. That was not the defect.

The defect was that a hand-maintained artifact can go stale silently. There was no moment at which anything failed. The build stayed green, the page kept rendering, the deploy kept succeeding, and the section kept saying something false. The only detection mechanism was a person happening to look. That mechanism had already been failing for three months when someone finally did.

So the fix was not to update the cards. It was to make the section incapable of going stale without something going red.

## The three pieces

### A goal is a contract a script can check

A goal states what "correct" means, in terms narrow enough that a program can decide whether you have it. "The homepage should feel current" is not a goal. "`data/release.json` equals the latest release returned by the GitHub API, and the deployed page renders that tag, within 24 hours" is a goal, because you can write the comparison.

Writing the goal is where most of the thinking happens. If you cannot express the contract as a check, you do not yet know what you are asking for.

### A gate is the check that fails loudly

The gate runs the comparison and exits non-zero when it does not hold. Two properties matter more than the code.

It has to be loud. A gate that logs a warning nobody reads is decoration.

It has to have been seen failing. A check that has never gone red is not known to work. It might be measuring nothing. A gate you have never watched fail is a false clear, and a false clear is worse than no gate, because you will trust it.

### A loop closes the gap, or stops

The loop is the automation that moves reality back onto the contract, with no human step in its steady state. If keeping the fact true requires someone to run a command once a week, you have written a runbook, not a loop.

The other half matters just as much. When a loop cannot close the gap safely, it stops and escalates rather than pushing through. A loop that force-merges past a red check has traded a stale page for a broken one.

The engineering is in the gate, not the loop. Writing a script that fetches a value and opens a pull request takes an afternoon. Writing a check that actually measures the thing you care about, and proving it fires, takes considerably longer. An ungated loop wanders, breaks things, and reports success.

## The worked example

Everything below lives in [aixgo-dev/web](https://github.com/aixgo-dev/web). The rebuild landed as [PR #19](https://github.com/aixgo-dev/web/pull/19), with the dispatch side as [aixgo-dev/aixgo#241](https://github.com/aixgo-dev/aixgo/pull/241).

### The goal

Recorded as [issue #20](https://github.com/aixgo-dev/web/issues/20), now closed with its evidence attached.

The homepage always names the latest aixgo release. The fact lives in [`data/release.json`](https://github.com/aixgo-dev/web/blob/main/data/release.json), and holds three fields and nothing else:

```json
{
  "date": "2026-05-02",
  "tag": "v0.7.4",
  "url": "https://github.com/aixgo-dev/aixgo/releases/tag/v0.7.4"
}
```

The shape is part of the contract. Release notes are free text written by whoever cut the release. Since no free-text field exists in this file, no release-note prose can reach the page unreviewed. The template reads the three values and writes its own sentence:

```go-html-template
<h2>Latest release: {{ $r.tag }} &middot; {{ dateFormat "2 January 2006" $r.date }}</h2>
```

[`scripts/release-sync.sh`](https://github.com/aixgo-dev/web/blob/main/scripts/release-sync.sh) writes the file from the API. It is twenty lines and deliberately dumb.

### The gate

[`scripts/check-release.sh`](https://github.com/aixgo-dev/web/blob/main/scripts/check-release.sh) takes check names as arguments and runs them. There are four, and where each one runs is a design decision, not an accident.

`shape` proves the file is the thing the template expects. It runs pre-merge on every pull request, in the `Release fact` job of [`lint.yml`](https://github.com/aixgo-dev/web/blob/main/.github/workflows/lint.yml):

```bash
tag=$(jq -r .tag "$FILE"); date=$(jq -r .date "$FILE"); url=$(jq -r .url "$FILE")
echo "$tag" | grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+$' || fail release-shape "tag '$tag' is not vX.Y.Z"
echo "$date" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' || fail release-shape "date '$date' is not YYYY-MM-DD"
[ "$url" = "https://github.com/${REPO}/releases/tag/${tag}" ] || fail release-shape "url '$url' does not match tag '$tag'"
extra=$(jq -r '[keys[] | select(. != "tag" and . != "date" and . != "url")] | length' "$FILE")
[ "$extra" = "0" ] || fail release-shape "unexpected keys in $FILE"
```

The last two lines are the ones that keep free text off the page. An extra key is a failure, not a warning.

`scope` constrains the bot. A pull request authored by the sync bot may change one file and no others. For a human author it passes trivially and says so:

```bash
bad=$(git diff --name-only "origin/${base}...HEAD" | grep -v '^data/release.json$' || true)
[ -z "$bad" ] || fail sync-scope "bot PR touches more than data/release.json: ${bad}"
```

`drift` is the contract itself, file against API:

```bash
want=$(gh api "repos/${REPO}/releases/latest" --jq .tag_name)
have=$(jq -r .tag "$FILE")
[ "$want" = "$have" ] || fail release-drift "$FILE says ${have}; the latest release is ${want}"
```

`live` fetches the deployed page and looks for the tag. It is the only check that catches a build that was green in data and never reached production.

`drift` and `live` deliberately do not run pre-merge. If they did, a new aixgo release would turn every unrelated typo-fix pull request red until someone synced the site. That is a gate punishing the wrong person for the wrong thing. Splitting by where a check runs is part of designing it.

### The loop

[`.github/workflows/release-sync.yml`](https://github.com/aixgo-dev/web/blob/main/.github/workflows/release-sync.yml) has two independent triggers, so one of them dying does not silence the section:

```yaml
on:
  repository_dispatch:
    types: [aixgo-release-published]
  schedule:
    - cron: "17 3 * * *"
  workflow_dispatch: {}
```

On a run where the fact changed, the job commits it to a branch, opens a pull request, flags it for auto-merge, waits for the merge to land, then polls the live page until it shows the new tag.

On a run where nothing changed, which is most days, the job degrades into the gate and runs `shape drift live`. This is the part worth copying. The daily cron is not a backup trigger for updates. It is a standing test that the whole path still works, so a silent failure anywhere becomes a red run within 24 hours.

When a run fails, the loop asks whether the previous run also failed:

```bash
prev=$(gh run list -R "$GITHUB_REPOSITORY" --workflow=release-sync --limit 2 \
  --json databaseId,conclusion --jq '.[1].conclusion // "none"')
if [ "$prev" != "failure" ]; then
  echo "first red run; the next scheduled run retries"
  exit 0
fi
```

One red run can be weather: an API blip, a Pages hiccup, a slow deploy. Two in a row is a stopped loop, and a stopped loop opens an issue titled "release-sync is red" instead of retrying forever in silence. It never force-lands anything.

### Two GitHub traps this loop had to route around

Both cost real time. Both are invisible until you hit them.

**Events raised by `GITHUB_TOKEN` start no workflows.** The obvious design is an `on: release` trigger in the website repo. It would never fire once, because GoReleaser publishes the release using `GITHUB_TOKEN`, and GitHub deliberately does not let token-raised events cascade into more workflow runs. The [aixgo release workflow](https://github.com/aixgo-dev/aixgo/blob/main/.github/workflows/release.yml) therefore ends with an explicit dispatch step using a GitHub App token:

```yaml
      - name: Dispatch release-sync
        env:
          GH_TOKEN: ${{ steps.app-token.outputs.token }}
        run: |
          gh api "repos/${{ github.repository_owner }}/web/dispatches" \
            -f event_type=aixgo-release-published
```

**The same rule breaks auto-merge.** A pull request opened with `GITHUB_TOKEN` triggers no CI. Required checks never report, so auto-merge waits forever and the loop hangs with no error to read. The sync job mints an App token and opens the pull request as the App, which is a distinct identity and does trigger CI.

## What the first drill caught

None of this ran on a real release first. It ran on a `workflow_dispatch` drill, on purpose, because a loop you have never watched fail is a loop you do not know anything about.

The drill found four defects, each merged as its own fix.

### An invalid workflow cannot alarm

[PR #22](https://github.com/aixgo-dev/web/pull/22). The workflow was not valid YAML. A multi-line `git commit -m` message inside a `run: |` block had unindented continuation lines, which terminate a literal block scalar. GitHub accepted the file, listed it by path, and registered it with no dispatchable triggers at all.

There was no error anywhere. The workflow existed and did nothing. A monitor that cannot parse cannot fire, so the failure mode of a broken alarm is silence, which looks exactly like health.

That catch produced a permanent addition to the gate rather than just a fix. `lint.yml` now runs `actionlint` on every pull request, and the job comment names its origin: the gate that #22 proved was missing. This is the method closing on itself. A drill found a class of failure the gate could not see, so the gate grew a check for it.

### The alarm died in its own failure mode

[PR #23](https://github.com/aixgo-dev/web/pull/23). A red run exposed that the escalation step itself crashed before it could open an issue. The `gh` CLI infers the repository from the local checkout, and the failure happened before the checkout step, so there was no local repository to infer from.

The class of failure that kills a run early is exactly the class the alarm exists for: bad credentials, a missing App installation, a runner that never got started. The alarm worked in every case where you did not need it. The fix is an explicit `-R "$GITHUB_REPOSITORY"` on all three calls, so the step depends on nothing that the failure could have taken away.

Test the alarm path, not just the happy path.

### The check measured the plumbing, not the thing

[PR #25](https://github.com/aixgo-dev/web/pull/25). The `live` check went red. The page was fine. Cloudflare bot protection was returning 403 to a bare `curl` from a datacenter runner.

The check was supposed to measure staleness. It was actually measuring whether a GitHub runner looked enough like a browser. Those two signals had been the same value up to that point, so the check looked like it worked. It now sends a browser User-Agent, and on a 403 specifically it verifies the deployment through the Pages origin the custom domain points at, logging the fallback so it can never pass quietly. A page that loads and does not contain the tag still fails on every path.

Ask what your check actually measures when it goes red, not what you meant it to measure.

### The failure path had never run

[PR #26](https://github.com/aixgo-dev/web/pull/26). The 403 fallback added by the previous fix could never execute. Under `set -e`, this is not protection:

```bash
fetch_shows "$SITE" "$tag"; rc=$?
```

A bare command returning non-zero terminates the script before `rc` is ever read. The correct idiom keeps the command inside a conditional context:

```bash
rc=0; fetch_shows "$SITE" "$tag" || rc=$?
```

The fallback was written, reviewed, and merged without anyone ever executing it, because the only way to reach it was to be blocked by Cloudflare. The fix was verified by forcing a 403 locally and watching the fallback path run.

Force the failure path before you ship it. Error handling that has never executed is a comment.

## The alarm fired for real

During bring-up, two consecutive red runs opened [issue #24](https://github.com/aixgo-dev/web/issues/24). The loop wrote it, not a person. It is now closed with its resolution.

That issue is the most valuable artifact in this whole exercise. It is the difference between a monitor believed to work and a monitor observed working. The [first fully green run](https://github.com/aixgo-dev/web/actions/runs/31363363974) came after it, with the live check logging its Cloudflare fallback rather than passing silently.

## Applying this to your own project

Pick the fact on your site or in your docs that is most likely already wrong. Then work through this in order.

1. **Write the contract as an equality.** Two values and a comparison. If you cannot name both sides, the goal is not finished.
2. **Shrink the artifact until nothing unchecked can enter it.** Three typed fields beat one prose paragraph. What the file cannot hold, the gate never has to police.
3. **Write the gate before the automation.** Run it by hand against known-good and known-bad inputs. Break the file on purpose and confirm it exits non-zero with a message that names the check.
4. **Decide where each check runs, and why.** Pre-merge checks must be about the change under review. Checks about the outside world belong on a schedule, or they will block work they have nothing to do with.
5. **Include a check on the deployed artifact.** Data being correct in the repository is not the same as the page being correct in production. Only one of those is what your reader sees.
6. **Make the scheduled run double as the gate.** On a quiet day the automation should still be proving the contract holds. That is what converts a silent failure into a red run with a bounded delay.
7. **Give the loop a stop condition.** Define what it does when it cannot close the gap. Opening an issue after two consecutive failures is a reasonable default. Retrying forever is not.
8. **Run a drill before you trust it.** Trigger it manually. Break the credentials on purpose. Make the check fail and watch the escalation open. Count how many defects the drill finds; on this one it was four, and every one of them would have shipped as a permanent blind spot.
9. **Record the evidence where the goal lives.** The goal issue should close with the run link, the failure that fired, and what each fix changed. Six months from now that record is the only thing that tells you whether the gate ever worked.

The measure of success is not that the fact is currently correct. It is that if the fact goes wrong tomorrow, something turns red before a reader notices.
