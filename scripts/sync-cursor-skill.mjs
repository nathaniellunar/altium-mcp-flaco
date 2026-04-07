#!/usr/bin/env node
/**
 * Dev helper: copy packaged skill into .cursor/skills so the repo picks it up locally.
 */
import { cpSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const src = join(root, "skills", "altium-mcp");
const dest = join(root, ".cursor", "skills", "altium-mcp");
mkdirSync(dirname(dest), { recursive: true });
cpSync(src, dest, { recursive: true });
console.log("Synced skills/altium-mcp -> .cursor/skills/altium-mcp");
