import { closeSync, openSync, unlinkSync, writeSync } from "node:fs";
import { join } from "node:path";

const sleep = (ms: number) => new Promise<void>((r) => setTimeout(r, ms));

export class LockTimeoutError extends Error {
  constructor(message = "Could not acquire bridge lock in time") {
    super(message);
    this.name = "LockTimeoutError";
  }
}

/**
 * Exclusive lock file under workspace to serialize Altium script invocations.
 */
export async function withBridgeLock<T>(
  workspaceRoot: string,
  fn: () => Promise<T>,
  options: { waitMs?: number; pollMs?: number } = {},
): Promise<T> {
  const waitMs = options.waitMs ?? 60_000;
  const pollMs = options.pollMs ?? 50;
  const lockPath = join(workspaceRoot, ".bridge.lock");
  const deadline = Date.now() + waitMs;
  let fd: number | undefined;

  while (Date.now() < deadline) {
    try {
      fd = openSync(lockPath, "wx");
      writeSync(fd, String(process.pid));
      closeSync(fd);
      fd = undefined;
      try {
        return await fn();
      } finally {
        try {
          unlinkSync(lockPath);
        } catch {
          /* ignore */
        }
      }
    } catch {
      if (fd !== undefined) {
        try {
          closeSync(fd);
        } catch {
          /* ignore */
        }
        fd = undefined;
      }
      await sleep(pollMs);
    }
  }

  throw new LockTimeoutError();
}
