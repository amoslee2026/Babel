/**
 * bb-hooks bridge (omp port of legacy Claude Code hook wiring)
 *
 * Reuses the legacy bb-hook-*.sh gate scripts (now at .omp/hooks/scripts/)
 * unchanged by translating omp hook events into the Claude hook stdin JSON
 * protocol they expect. Exit code 2 => block; stderr surfaced via logger + UI.
 *
 * Event mapping (from the legacy Claude Code settings.json):
 *   tool_call(bash)       -> bb-hook-commit-quality-gate.sh, bb-hook-validate-bash-cmd.sh
 *   tool_call(write|edit)  -> bb-hook-write-arch-freeze-check.sh
 *   tool_result(write|edit)-> bb-hook-change-propagate.sh, bb-hook-pipeline-advance.sh
 *   before_agent_start    -> bb-hook-validate-input-schema.sh (prompt schema gate;
 *                            omp cannot reject a started turn, so exit 2 degrades
 *                            to a blocking-style warning via UI/logger)
 *   session_shutdown      -> bb-hook-session-summarize.sh
 */
import { spawnSync } from "node:child_process";
import path from "node:path";

const SCRIPTS = [
	"bb-hook-commit-quality-gate.sh",
	"bb-hook-validate-bash-cmd.sh",
	"bb-hook-write-arch-freeze-check.sh",
	"bb-hook-change-propagate.sh",
	"bb-hook-pipeline-advance.sh",
	"bb-hook-validate-input-schema.sh",
	"bb-hook-session-summarize.sh",
];

export default function (pi) {
	// Resolve the repo root from this file (<root>/.omp/hooks/pre/bb-hooks-bridge.js)
	// so hooks work regardless of the process cwd.
	const HOOK_DIR = path.dirname(new URL(import.meta.url).pathname);
	const PROJECT_ROOT = path.resolve(HOOK_DIR, "..", "..", "..");
	const SCRIPT_DIR = path.join(PROJECT_ROOT, ".omp", "hooks", "scripts");
	const isWriteTool = (name) => name === "write" || name === "edit";

	const runScript = (name, payload) => {
		const script = path.join(SCRIPT_DIR, name);
		const r = spawnSync("bash", [script], {
			input: JSON.stringify(payload),
			encoding: "utf8",
			cwd: PROJECT_ROOT,
			env: { ...process.env, CLAUDE_PROJECT_DIR: PROJECT_ROOT },
			timeout: 30_000,
		});
		return { code: r.status, stderr: (r.stderr || "").trim() };
	};

	const surface = (ctx, text) => {
		if (!text) return;
		try {
			pi.logger?.warn?.(text);
			ctx?.ui?.notify?.(text);
		} catch {}
	};

	const gate = (names, payload, ctx) => {
		for (const name of names) {
			const { code, stderr } = runScript(name, payload);
			if (code === 2) return { block: true, reason: stderr || `blocked by ${name}` };
			if (stderr) surface(ctx, stderr);
		}
		return undefined;
	};

	// Legacy write tool input may use file_path; omp uses path.
	const asClaudeToolInput = (input = {}) => ({
		...input,
		file_path: input.file_path ?? input.path,
	});

	pi.on("tool_call", async (event, ctx) => {
		const { toolName, input = {} } = event;
		if (toolName === "bash") {
			return gate(
				SCRIPTS.slice(0, 2),
				{ tool_name: "Bash", tool_input: { command: input.command ?? "" } },
				ctx,
			);
		}
		if (isWriteTool(toolName)) {
			return gate(
				[SCRIPTS[2]],
				{ tool_name: "Write", tool_input: asClaudeToolInput(input) },
				ctx,
			);
		}
		return undefined;
	});

	pi.on("tool_result", async (event, ctx) => {
		if (!isWriteTool(event.toolName) || event.isError) return;
		gate(
			SCRIPTS.slice(3, 5),
			{ tool_name: "Write", tool_input: asClaudeToolInput(event.input ?? {}) },
			ctx,
		);
		return undefined;
	});

	pi.on("before_agent_start", async (event, ctx) => {
		const msg = event?.message;
		const prompt =
			typeof msg?.content === "string"
				? msg.content
				: Array.isArray(msg?.content)
					? msg.content.map((c) => c?.text ?? "").join("\n")
					: "";
		if (!prompt) return undefined;
		gate([SCRIPTS[5]], { prompt }, ctx);
		return undefined;
	});

	pi.on("session_shutdown", async () => {
		runScript(SCRIPTS[6], {});
		return undefined;
	});
}
