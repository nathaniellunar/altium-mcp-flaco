# Installing the Altium MCP Cursor skill

The skill teaches Cursor's agent how to use the **altium-mcp** MCP tools and Altium-side requirements. It is optional if your client already injects the server's MCP `instructions` text.

## Option A — CLI

After a global install:

```bash
altium-mcp-install-skill
```

From a project dependency (no global bin on PATH):

```bash
npx altium-mcp-install-skill
```

Copies this folder from the installed package into your user Cursor skills directory:

- **Windows**: `%USERPROFILE%\.cursor\skills\altium-mcp\`
- **macOS / Linux**: `~/.cursor/skills/altium-mcp/`

Run again after upgrading the package if the skill content changed.

## Option B — Manual copy

1. Locate this folder (`skills/altium-mcp` in the Git repo, or `node_modules/altium-mcp/skills/altium-mcp` after `npm install`).
2. Copy the entire `altium-mcp` folder into `.cursor/skills/`:
   - **User-wide (recommended for any project using MCP)**: `~/.cursor/skills/altium-mcp/`
   - **Single repo only**: `<your-repo>/.cursor/skills/altium-mcp/`

Ensure `SKILL.md` ends up at `.cursor/skills/altium-mcp/SKILL.md`.

## Other MCP clients

Clients that support MCP **server instructions** receive setup and tool guidance on connect without installing this file. Clients without that feature may rely on project documentation or custom prompts.
