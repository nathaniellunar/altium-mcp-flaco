#!/usr/bin/env node
/**
 * Install the Cursor Agent Skill into the current user's ~/.cursor/skills/altium-mcp.
 * Safe to re-run (overwrites SKILL.md and siblings).
 */
import { cpSync, existsSync, mkdirSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const src = join(root, "skills", "altium-mcp");
if (!existsSync(join(src, "SKILL.md"))) {
  console.error("altium-mcp: skills/altium-mcp/SKILL.md not found (broken package layout).");
  process.exit(1);
}

const dest = join(homedir(), ".cursor", "skills", "altium-mcp");
mkdirSync(dirname(dest), { recursive: true });
cpSync(src, dest, { recursive: true });
console.log(`Installed Cursor skill: ${dest}`);
