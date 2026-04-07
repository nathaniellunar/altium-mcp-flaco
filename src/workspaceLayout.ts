import {
  cpSync,
  existsSync,
  mkdirSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { join } from "node:path";
import {
  ALTIUM_BUNDLE_FINGERPRINT_FILENAME,
  computeBundledAltiumScriptsFingerprint,
} from "./altiumBundleFingerprint.js";

/**
 * Ensures workspace/AltiumScript mirrors bundledScriptsDir when bundle content changes.
 * Uses a content fingerprint so Altium touching file mtimes in the workspace does not block updates.
 */
export function ensureAltiumScriptBundle(
  workspaceRoot: string,
  bundledScriptsDir: string,
): void {
  mkdirSync(workspaceRoot, { recursive: true });

  const dest = join(workspaceRoot, "AltiumScript");
  const marker = join(dest, "Altium_API.PrjScr");
  const stateFile = join(dest, ALTIUM_BUNDLE_FINGERPRINT_FILENAME);

  let currentFingerprint: string;
  try {
    currentFingerprint =
      computeBundledAltiumScriptsFingerprint(bundledScriptsDir);
  } catch {
    return;
  }

  let needsSync = true;
  if (existsSync(marker) && existsSync(stateFile)) {
    try {
      const previous = readFileSync(stateFile, "utf8").trim();
      if (previous === currentFingerprint) needsSync = false;
    } catch {
      needsSync = true;
    }
  }

  if (!needsSync) return;

  rmSync(dest, { recursive: true, force: true });
  cpSync(bundledScriptsDir, dest, { recursive: true });
  writeFileSync(
    join(dest, ALTIUM_BUNDLE_FINGERPRINT_FILENAME),
    `${currentFingerprint}\n`,
    "utf8",
  );
}

export function scriptProjectPath(workspaceRoot: string): string {
  return join(workspaceRoot, "AltiumScript", "Altium_API.PrjScr");
}
