import { afterEach, describe, expect, test } from "vitest";
import { readFile, writeFile } from "node:fs/promises";
import { slCaptureLesson } from "../../SL-src/SL-core/SL-capture.js";
import {
  slParseMarkdown,
  slStringifyMarkdown,
} from "../../SL-src/SL-core/SL-frontmatter.js";
import { slInstall } from "../../SL-src/SL-core/SL-installer.js";
import { slLoadRegistry } from "../../SL-src/SL-core/SL-registry.js";
import { slSynchronizeResourceProjection } from "../../SL-src/SL-core/SL-resource.js";
import { slRetrieveArtifacts } from "../../SL-src/SL-core/SL-retrieval.js";
import type { SLChange } from "../../SL-src/SL-core/SL-types.js";
import {
  slLoadUsageEvents,
  slSynchronizeUsageProjection,
} from "../../SL-src/SL-core/SL-usage.js";
import { slResolveInside } from "../../SL-src/SL-core/SL-utils.js";
import { slValidateRepository } from "../../SL-src/SL-validation/SL-validation.js";
import {
  slCreateTestRepository,
  slRemoveTestRepository,
} from "../SL-fixtures/SL-test-repository.js";

const repositories: string[] = [];

afterEach(async () => {
  await Promise.all(repositories.splice(0).map(slRemoveTestRepository));
});

describe("SL capture and index", () => {
  test("creates deterministic registered evidence", async () => {
    const root = await slCreateTestRepository();
    repositories.push(root);
    await slInstall(root, "init", false);

    const result = await slCaptureLesson(root, {
      title: "Command timeout must match busy timeout",
      kind: "pitfall",
      scope: "database",
      triggers: ["sqlite busy timeout", "command timeout"],
      dryRun: false,
      now: new Date("2026-09-03T10:00:00.000Z"),
    });

    expect(result.id).toBe("SL-20260903-COMMAND-TIMEOUT-MUST-MATCH-BUSY-TIMEOUT");
    expect(result.path).toBe(
      ".github/sl-learning/sl-lessons/2026-09/sl-2026-09-03-command-timeout-must-match-busy-timeout.md",
    );
    const registry = await slLoadRegistry(root);
    const lesson = registry.artifacts.find((artifact) => artifact.id === result.id);
    expect(lesson).toMatchObject({
      classification: "evidence",
      status: "raw",
      pinned: false,
    });

    const issues = await slValidateRepository(root);
    expect(issues).toEqual([]);
  });

  test("seeds complete historical evidence without synthetic reuse", async () => {
    const root = await slCreateTestRepository();
    repositories.push(root);
    await slInstall(root, "init", false);

    const result = await slCaptureLesson(root, {
      title: "Metric dimensions require trusted bounded sources",
      kind: "pitfall",
      scope: "telemetry",
      triggers: ["metric dimensions", "request latency telemetry"],
      dryRun: false,
      now: new Date("2026-09-17T10:00:00.000Z"),
    });
    const lessonPath = slResolveInside(root, result.path);
    const generated = slParseMarkdown<Record<string, unknown>>(
      await readFile(lessonPath, "utf8"),
    );
    const body = [
      "## Context",
      "When emitting request metrics, use authenticated claims and matched route metadata.",
      "Evidence: commit ba741e28 and current MetricReporterMiddleware tests.",
      "",
      "## What did NOT work",
      "- Raw request headers and paths allowed spoofed, unbounded dimensions.",
      "",
      "## Why",
      "Trusted bounded dimensions prevent sensitive data exposure and cardinality growth.",
      "",
      "## Re-use cue",
      "- Retrieve before adding or changing request metric dimensions.",
    ].join("\n");
    await writeFile(
      lessonPath,
      slStringifyMarkdown(generated.frontmatter, body),
      "utf8",
    );

    const completed = slParseMarkdown<Record<string, unknown>>(
      await readFile(lessonPath, "utf8"),
    );
    expect(completed.frontmatter).toEqual(generated.frontmatter);
    expect(completed.body).not.toContain("Replace with");
    expect(completed.body).not.toContain("Describe the verified situation");

    const retrieved = await slRetrieveArtifacts(
      root,
      "src/HealthAI-RP/Middleware/MetricReporterMiddleware.cs",
      "metric dimensions",
    );
    expect(retrieved.artifacts).toEqual([
      expect.objectContaining({
        id: result.id,
        path: result.path,
        status: "raw",
      }),
    ]);
    expect(await slLoadUsageEvents(root)).toEqual([]);
    const projectionChanges: SLChange[] = [];
    await slSynchronizeUsageProjection(root, false, projectionChanges);
    await slSynchronizeResourceProjection(root, false, projectionChanges);
    expect(projectionChanges).not.toHaveLength(0);
    expect(projectionChanges.every((change) => change.action === "skip")).toBe(true);
    expect(await slValidateRepository(root)).toEqual([]);
  });
});
