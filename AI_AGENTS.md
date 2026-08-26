# Strata — Optional AI Agent Integration

## Goal

Provide useful coding-agent integration without bloating the base ISO or forcing users into a specific AI vendor.

## Principles

- optional,
- lazy-installed,
- provider-neutral,
- no agent required for normal system operation,
- no provider credentials stored by the project,
- no background agent services enabled by default.

## Initial Providers

Potential support:

- OpenAI Codex CLI
- Claude Code
- OpenCode
- Gemini CLI
- GitHub Copilot CLI

## Proposed User Experience

Future helper:

```bash
agent list
agent install codex
agent install claude
agent default codex
agent run
```

This interface is illustrative, not a mandatory implementation.

## Provider Definitions

Prefer simple metadata/config definitions rather than hard-coded provider logic.

Example conceptual structure:

```text
agents/
├── codex.conf
├── claude.conf
├── opencode.conf
├── gemini.conf
└── copilot.conf
```

Each definition may describe:

- display name,
- upstream install method,
- executable name,
- update method,
- authentication notes,
- supported architectures.

## Project-Aware Agent Knowledge

Provide a provider-neutral project skill/instruction set containing:

- Debian-first architecture rule,
- package policy,
- repository structure,
- build instructions,
- Hyprland locations,
- Quickshell locations,
- test commands,
- release rules,
- prohibited architectural shortcuts.

The intent is that a coding agent can safely make changes without accidentally turning the project into a Debian fork.

## Security

Do not:

- ship API keys,
- auto-enable remote access,
- run autonomous background agents by default,
- grant passwordless root privileges to agent tools,
- modify sudoers for AI agents without explicit user action.
