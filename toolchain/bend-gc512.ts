// Build-only adapter for the pinned Bend 2 compiler. The source on disk stays intact.
import { plugin } from "bun";
import { createHash } from "node:crypto";
import { readFileSync, realpathSync } from "node:fs";
import { dirname, resolve } from "node:path";

if (Bun.version !== "1.4.2") {
  throw new Error("Juice Bend compiler adapter requires Bun 1.4.2");
}

const expected = "5ae06d6c44581bd7e0e2f5952e402659c9be408f79a5a4e86ff23e5be9844ce6";
const target = realpathSync(resolve(dirname(realpathSync(process.argv[1])), "comp.ts"));
const filter = new RegExp("^" + target.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + "$");
const before = `function memo_gc(): void {
  Object.values(FL.memo).forEach((m) => m.clear());
}`;
const after = `let juice_gc_calls = 0;
function memo_gc(): void {
  Object.values(FL.memo).forEach((m) => m.clear());
  if (++juice_gc_calls % 512 === 0) {
    Bun.gc(true);
  }
}`;

function transformed(): string {
  const bytes = readFileSync(target);
  if (createHash("sha256").update(bytes).digest("hex") !== expected) {
    throw new Error("Juice Bend compiler adapter: pinned comp.ts hash mismatch");
  }
  const source = bytes.toString("utf8");
  if (source.split(before).length !== 2) {
    throw new Error("Juice Bend compiler adapter: memo_gc anchor mismatch");
  }
  return source.replace(before, after);
}

// Fail at preload time even if the entry does not import the compiler.
transformed();
let applied = false;
plugin({
  name: "juice-bend-compiler-gc512",
  setup(build) {
    build.onLoad({ filter, namespace: "file" }, (args) => {
      if (realpathSync(args.path) !== target) throw new Error("Compiler adapter target changed");
      const contents = transformed();
      applied = true;
      return { contents, loader: "ts" };
    });
  },
});
process.on("exit", (code) => {
  if (code === 0 && !applied) {
    console.error("Juice Bend compiler adapter: compiler hook was not used");
    process.exitCode = 1;
  }
});
