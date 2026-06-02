---
description: Guided feature development for the fd1 Garmin ConnectIQ watch app. Interviews the user, plans with Opus in plan mode, stores plan, implements, builds, and runs the emulator for validation.
---

You are running the `/feature-creator` skill for the **fd1** Garmin freediving watch app.

## Project context

- **Language:** Monkey C (Garmin ConnectIQ)
- **Source:** `fd1/source/` — main files: `Fd1App.mc`, `Fd1State.mc` (in `Fd1Util` module), `Fd1View.mc`, `Fd1Delegate.mc`, `Fd1MenuDelegate.mc`, `Fd1SessionRecorder.mc`
- **SDK:** `~/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-7.3.1-2024-09-23-df7b5816a`
- **Developer key:** `~/Documents/src/developer_key`
- **Build output:** `fd1/bin/fd1.prg`
- **Target device:** `instinct2s` (also `instinct2x`, `fenix6pro`)
- **Build command:** `monkeyc -f fd1/monkey.jungle -y ~/Documents/src/developer_key -o fd1/bin/fd1.prg -d instinct2s`
- **Run command:** open `ConnectIQ.app` then `monkeydo fd1/bin/fd1.prg instinct2s`

---

## Step 1 — Understand the feature

If `$ARGUMENTS` is non-empty, use it as the feature description. Otherwise ask:

**"What feature do you want to add to the fd1 watch app?"**

After receiving the initial description, ask targeted follow-up questions to clarify anything ambiguous. Focus on:
- What triggers the behavior (button, timer, sensor, menu)?
- What should appear on screen?
- How does it interact with the existing state machine (REST/DIVE modes)?
- Should it be persisted in settings?
- Any edge cases specific to freediving (e.g. behavior mid-dive)?

Keep questions focused — ask only what you genuinely can't infer from the codebase. Group related questions into one message.

---

## Step 2 — Plan with Opus in plan mode

Once you have enough information:

1. **Enter plan mode** using the `EnterPlanMode` tool.
2. **Spawn an Explore agent** to read the relevant source files and understand existing patterns.
3. **Spawn a Plan agent** using `model: "opus"` to design the implementation. Give it full context: feature description, user answers, and findings from the Explore agent.
4. **Write the plan** to `/Users/Artur_Belski/.claude/plans/<slug>.md` where `<slug>` is a short kebab-case name for the feature.
5. **Exit plan mode** using `ExitPlanMode` to show the plan to the user for approval.

The plan file must include:
- **Context** — why this feature is being added
- **Files to modify** — specific `.mc` files and what changes
- **Implementation steps** — ordered, concrete
- **Verification** — how to confirm it works in the simulator

---

## Step 3 — Implement or iterate

After the user reviews the plan, ask:

**"Should I implement this now, or do you want to make corrections to the plan first?"**

- If **corrections**: update the plan file with the user's feedback, show the revised plan, and ask again.
- If **implement**: proceed to Step 4.

---

## Step 4 — Implement

Follow the approved plan. Edit only the files listed. After all changes:

- Run a quick sanity check (re-read edited sections).
- Do not add unrequested features or refactor unrelated code.

---

## Step 5 — Build

Run the build:

```bash
SDK="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-7.3.1-2024-09-23-df7b5816a"
"$SDK/bin/monkeyc" \
  -f /Users/Artur_Belski/Documents/src/fd1/fd1/monkey.jungle \
  -y "$HOME/Documents/src/developer_key" \
  -o /Users/Artur_Belski/Documents/src/fd1/fd1/bin/fd1.prg \
  -d instinct2s
```

If the build **fails**: fix the compiler errors and rebuild. Report what was wrong and what you fixed.

If the build **succeeds**: proceed to Step 6.

---

## Step 6 — Run emulator

```bash
SDK="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-7.3.1-2024-09-23-df7b5816a"
open "$SDK/bin/ConnectIQ.app"
# wait 3 seconds, then:
"$SDK/bin/monkeydo" /Users/Artur_Belski/Documents/src/fd1/fd1/bin/fd1.prg instinct2s &
```

Tell the user:
- Build result (success / errors fixed)
- That the simulator is now running with the new build
- How to test the feature (what to look for or which buttons to press)
