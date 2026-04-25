# Codex AGENTS and Hooks Reference

Reference links used for the NuguSauce agent/harness structure:

- https://developers.openai.com/codex/guides/agents-md
- https://developers.openai.com/codex/hooks
- https://developers.openai.com/codex/rules

## Local Decision

- Use `AGENTS.md` as enforceable routing and operating guidance.
- Use nested `AGENTS.md` for areas with distinct rules.
- Use `docs/` for detailed knowledge that should be read only when routed.
- Use hooks as guardrails for context injection and verification reminders.
- Do not treat hooks as the final security boundary; tests, review, and CI remain the hard gates.
