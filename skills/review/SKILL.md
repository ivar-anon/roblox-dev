---
description: Run a structured security, data-safety, performance and typing review of Roblox/Luau code using the roblox-reviewer agent. Use when asked to review Roblox code, audit a game for exploits or leaks, or before shipping a system.
disable-model-invocation: true
---

# /roblox-dev:review — Audit Roblox Code

Run a structured audit of the Luau code targeted by `$ARGUMENTS` (a path,
system name, or "everything"). If no target is given, review
`src/` (or the repository's Luau sources).

## Procedure

1. Identify the target files. For large codebases, prioritize in this order:
   remote handlers, DataStore/persistence code, per-frame loops, then
   everything else.
2. Launch the **roblox-reviewer** agent on the target. Pass it the file list
   and tell it which of the four lenses to emphasize if the user asked for a
   specific one (security / data / performance / typing).
3. Present findings as a table sorted by severity:

   | # | Severity | File:Line | Finding | Fix |

   Severities: **Critical** (exploitable or data loss), **High** (leak or
   crash under load), **Medium** (correctness risk, type hole), **Low**
   (style, maintainability).
4. Offer to fix the Critical and High findings immediately, in severity
   order. Fix only what the user confirms.

## Honesty rules

- Report only findings verifiable in the actual code shown — no speculative
  "might be a problem" filler to pad the table.
- If a pattern looks wrong but depends on code you haven't seen (e.g. a
  validation wrapper defined elsewhere), say exactly that and list the file
  you'd need.
- An empty or short findings table for clean code is a valid, good result.
