# CLAUDE.md — Yahoo! KeyKey rewrite

## Always apply: The Four Principles

For ALL work in this project, follow these four principles (the
`anthropic-skills:the-four-principles` skill). This is a standing rule.

### 1. Think Before Coding
Don't assume. Don't hide confusion. Surface tradeoffs.
- State assumptions explicitly; if uncertain, ask.
- If multiple interpretations exist, present them — don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop, name it, and ask.

### 2. Simplicity First
Minimum code that solves the problem. Nothing speculative.
- No features beyond what was asked.
- No abstractions for single-use code.
- No unrequested "flexibility" or "configurability".
- No error handling for impossible scenarios.
- If 200 lines could be 50, rewrite it.

### 3. Surgical Changes
Touch only what you must. Clean up only your own mess.
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style even if you'd do it differently.
- Note unrelated dead code; don't delete it unless asked.
- Remove only the imports/variables your own changes orphaned.
- Every changed line should trace directly to the request.

### 4. Goal-Driven Execution
Define success criteria. Loop until verified.
- Turn tasks into verifiable goals (write the test, then make it pass).
- For multi-step tasks, state a brief plan with a verify check per step.

## Project conventions

- **Git identity:** commit as `teddychan <teddychan@gmail.com>` (NOT the work email).
- **Stack:** Swift + InputMethodKit + AppKit/SwiftUI; target macOS arm64 + x86_64.
- **Specs live in** `docs/superpowers/specs/`.
