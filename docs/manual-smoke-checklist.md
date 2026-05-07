# Token Meter Manual Smoke Checklist

Use this checklist before release or after provider-related UI changes.

## Claude Regression

1. Open the app from the menu bar.
   Expected: the default usage tab is `Claude`.

2. Confirm the Claude view renders session, weekly, and project sections.
   Expected: Claude shows the existing session gauge, weekly gauge, and project breakdown without needing to switch tabs.

3. Change the Claude project period to `7 days`, then `all`.
   Expected: the Claude project list updates and the selected period stays on Claude.

4. Click refresh while the Claude tab is selected.
   Expected: Claude data refreshes without switching to Codex, and the Claude period selection is preserved.

5. Test a Claude logged-out state on a machine where Claude credentials are unavailable.
   Expected: the app shows the existing Claude login guidance instead of crashing or showing Codex copy.

## Codex Experience

1. Switch from `Claude` to `Codex`.
   Expected: the popover replaces the Claude gauges with the Codex status card and Codex project section.

2. Change the Codex project period, then click refresh.
   Expected: the app stays on `Codex`, keeps the selected period, and refreshes only Codex state.

3. Test a Codex logged-in machine with local Codex usage already present.
   Expected: the Codex tab shows either availability or usage status plus project rows sorted by highest token usage first.

4. Test a Codex logged-out machine.
   Expected: the Codex tab shows login-required guidance telling the user to sign in locally and refresh.

5. Test a Codex machine with login available but no recent local usage.
   Expected: the project section shows a Codex empty-state message instead of an unavailable error.

## External User Setup

1. On a second macOS user account or a second Mac, install and launch Token Meter.
   Expected: the app launches without machine-specific configuration or path edits.

2. Sign in to Codex locally on that user account, then reopen or refresh Token Meter.
   Expected: Token Meter reads Codex state from the current user's local environment and the Codex tab becomes usable.

3. Read the README setup section before testing.
   Expected: the documented Codex prerequisites, local sign in step, and current limitations match the app behavior.
