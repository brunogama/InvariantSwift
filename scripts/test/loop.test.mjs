import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import {
	chmod,
	mkdir,
	mkdtemp,
	readFile,
	rm,
	symlink,
	writeFile,
} from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { AsyncLocalStorage } from "node:async_hooks";
import { test as nodeTest } from "node:test";

const packageRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const loopScript = join(packageRoot, "loop.sh");

// Expose the current test's AbortSignal to the run()/runLoop() helpers without
// forcing every test to thread it through. node:test aborts t.signal when a
// test times out; run() uses it to kill a spawned loop.sh child so an orphaned
// subprocess cannot keep the event loop alive and hang the suite.
const testSignal = new AsyncLocalStorage();
function test(name, ...rest) {
	const hasOptions = typeof rest[0] === "object" && rest[0] !== null;
	const options = hasOptions ? rest[0] : undefined;
	const fn = hasOptions ? rest[1] : rest[0];
	return nodeTest(name, options, async (t) => testSignal.run(t.signal, () => fn(t)));
}

function collect(stream) {
	let output = "";
	stream.setEncoding("utf8");
	stream.on("data", (chunk) => {
		output += chunk;
	});
	return () => output;
}

function waitForExit(child) {
	return new Promise((resolveExit, reject) => {
		child.once("error", reject);
		child.once("exit", (code, signal) => resolveExit({ code, signal }));
	});
}

async function run(command, args, options = {}) {
	const child = spawn(command, args, {
		stdio: ["ignore", "pipe", "pipe"],
		...options,
	});
	const stdout = collect(child.stdout);
	const stderr = collect(child.stderr);
	// loop.sh wraps its Pi RPC call in `>(tee ...)` process substitutions whose
	// tee processes inherit this child's stdio pipe descriptors. If node:test
	// aborts the owning test on its timeout while the Pi RPC call is still
	// running, the child can outlive the test and hold these pipes open, which
	// keeps the event loop alive and makes `node --test` hang forever. Kill the
	// child when the test's AbortSignal fires so the suite always terminates.
	const signal = testSignal.getStore();
	if (signal) {
		const onAbort = () => {
			try {
				child.kill("SIGKILL");
			} catch {}
		};
		if (signal.aborted) onAbort();
		else signal.addEventListener("abort", onAbort, { once: true });
	}
	const exit = await waitForExit(child);
	return { ...exit, stdout: stdout(), stderr: stderr() };
}

async function createHarness(issueNumbers = [2, 3]) {
	const base = await mkdtemp(join(tmpdir(), "loop-v2-"));
	const repository = join(base, "repository");
	const bin = join(base, "bin");
	const stateFile = join(base, "github-state.json");
	const mutationsFile = join(base, "mutations.jsonl");
	const rpcCallsFile = join(base, "rpc-calls.txt");
	const piArgsFile = join(base, "pi-args.jsonl");
	const promptsFile = join(base, "prompts.jsonl");
	await mkdir(repository, { recursive: true });
	await mkdir(bin, { recursive: true });
	const installedLoopScript = join(bin, "loop.sh");
	await symlink(loopScript, installedLoopScript);
	await writeFile(join(repository, "README.md"), "# Target repository\n");
	await writeFile(join(repository, ".gitignore"), ".ralph/runs/\n");
	await writeFile(
		stateFile,
		`${JSON.stringify({
			repositoryLabels: ["ready-for-agent", "ready-for-human", "in-progress"],
			issues: Object.fromEntries(
				issueNumbers.map((number) => [
					number,
					{
						number,
						title: `Ticket ${number}`,
						body: `Implement ticket ${number}`,
						state: "OPEN",
						labels: [{ name: "ready-for-agent" }],
						blockedBy: 0,
						comments: [],
						assignees: [],
					},
				]),
			),
		})}\n`,
	);

	const fakePi = join(bin, "fake-pi.mjs");
	await writeFile(
		fakePi,
		`#!/usr/bin/env node
import { appendFileSync, writeFileSync } from "node:fs";
import { execFileSync } from "node:child_process";

const args = process.argv.slice(2);
appendFileSync(process.env.FAKE_PI_ARGS, JSON.stringify(args) + "\\n");
const issueName = args[args.indexOf("--name") + 1];
const issueNumber = Number(issueName.match(/issue-(\\d+)/u)[1]);
const mode = process.env.FAKE_RPC_MODE ?? "success";
let buffer = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", (chunk) => {
  buffer += chunk;
  while (buffer.includes("\\n")) {
    const newline = buffer.indexOf("\\n");
    const line = buffer.slice(0, newline);
    buffer = buffer.slice(newline + 1);
    if (!line) continue;
    const command = JSON.parse(line);
    if (command.type === "get_session_stats") {
      console.log(JSON.stringify({
        id: command.id,
        type: "response",
        command: "get_session_stats",
        success: true,
        data: { tokens: { total: 100 }, cost: 0.01 },
      }));
      continue;
    }
    if (command.type !== "prompt") continue;
    appendFileSync(process.env.FAKE_RPC_CALLS, issueNumber + "\\n");
    appendFileSync(process.env.FAKE_PROMPTS, JSON.stringify(command.message) + "\\n");
    console.log(JSON.stringify({ id: command.id, type: "response", command: "prompt", success: true }));
    console.log(JSON.stringify({ type: "agent_start" }));
    if (mode === "hang") return;
    if (mode === "settle-only") {
      console.log(JSON.stringify({ type: "agent_settled" }));
      return;
    }
    if (mode !== "missing-commit") {
      writeFileSync("ticket-" + issueNumber + ".txt", "completed\\n");
      execFileSync("git", ["add", "ticket-" + issueNumber + ".txt"]);
      execFileSync("git", ["commit", "-m", "Complete ticket " + issueNumber], { stdio: "ignore" });
    }
    const commit = execFileSync("git", ["rev-parse", "HEAD"], { encoding: "utf8" }).trim();
    if (mode === "dirty-worktree") writeFileSync("leftover.txt", "dirty\\n");
    const report = {
      status: mode === "malformed-report" ? "incomplete" : "complete",
      implementation: { status: "complete", summary: "implemented ticket" },
      verification: { status: "complete", summary: "focused and full checks passed" },
      code_review: { status: "complete", summary: "review completed without findings" },
      commit,
    };
    const text = "RALPH_COMPLETION_REPORT=" + JSON.stringify(report);
    console.log(JSON.stringify({
      type: "message_end",
      message: { role: "assistant", content: [{ type: "text", text }], usage: { totalTokens: 100 } },
    }));
    console.log(JSON.stringify({ type: "agent_settled" }));
  }
});
`,
	);
	await chmod(fakePi, 0o755);

	const terminatingRpc = join(bin, "terminating-rpc.sh");
	await writeFile(terminatingRpc, "#!/usr/bin/env bash\nexit 130\n");
	await chmod(terminatingRpc, 0o755);

	const fakeGitHub = join(bin, "fake-gh.mjs");
	await writeFile(
		fakeGitHub,
		`#!/usr/bin/env node
import { appendFileSync, existsSync, readFileSync, writeFileSync } from "node:fs";

const args = process.argv.slice(2);
const state = JSON.parse(readFileSync(process.env.FAKE_GH_STATE, "utf8"));
const save = () => writeFileSync(process.env.FAKE_GH_STATE, JSON.stringify(state) + "\\n");
const issueNumber = () => Number(args.find((value) => /^\\d+$/u.test(value)));
const issue = () => state.issues[issueNumber()];
const mutate = (operation, number) => appendFileSync(process.env.FAKE_MUTATIONS, JSON.stringify({ operation, number }) + "\\n");

if (args[0] === "repo" && args[1] === "view") {
  process.stdout.write("owner/repository\\n");
} else if (args[0] === "label" && args[1] === "list") {
  process.stdout.write(state.repositoryLabels.join("\\n") + "\\n");
} else if (args[0] === "label" && args[1] === "create") {
  const name = args[2];
  if (!state.repositoryLabels.includes(name)) {
    if (process.env.FAKE_LABEL_CREATE_RACE) {
      state.repositoryLabels.push(name);
      save();
      process.exitCode = 1;
    } else if (process.env.FAKE_FAIL_LABEL_CREATE) {
      process.exitCode = 1;
    } else {
      state.repositoryLabels.push(name);
      appendFileSync(process.env.FAKE_MUTATIONS, JSON.stringify({ operation: "create-label", name }) + "\\n");
      save();
    }
  }
} else if (args[0] === "issue" && args[1] === "view") {
  process.stdout.write(JSON.stringify(issue()) + "\\n");
} else if (args[0] === "api" && args[1] === "user") {
  process.stdout.write("test-user\\n");
} else if (args[0] === "api" && args[1].endsWith("/parent")) {
  process.stdout.write(JSON.stringify({ number: 1, title: "Parent spec", body: "Read-only parent context" }) + "\\n");
} else if (args[0] === "api" && args[1].endsWith("/sub_issues")) {
  process.stdout.write("[]\\n");
} else if (args[0] === "api") {
  const number = Number(args[1].match(/issues\\/(\\d+)/u)[1]);
  process.stdout.write(String(state.issues[number].blockedBy) + "\\n");
} else if (args[0] === "issue" && args[1] === "edit") {
  const current = issue();
  if (args.includes("--add-assignee")) {
    current.assignees = [{ login: "test-user" }];
    if (process.env.FAKE_ADD_RIVAL_ASSIGNEE) current.assignees.push({ login: "rival-user" });
    mutate("assign", current.number);
  }
  if (args.includes("--remove-assignee")) {
    current.assignees = current.assignees.filter(({ login }) => login !== "test-user");
    mutate("unassign", current.number);
  }
  if (args.includes("--add-label")) {
    const name = args[args.indexOf("--add-label") + 1];
    if (!current.labels.some((label) => label.name === name)) current.labels.push({ name });
    mutate("add-label", current.number);
  }
  if (args.includes("--remove-label")) {
    const name = args[args.indexOf("--remove-label") + 1];
    current.labels = current.labels.filter((label) => label.name !== name);
    mutate("remove-label", current.number);
  }
  save();
} else if (args[0] === "issue" && args[1] === "comment") {
  const current = issue();
  const bodyFile = args[args.indexOf("--body-file") + 1];
  const body = readFileSync(bodyFile, "utf8");
  const isCompletion = body.includes("ralph-loop-v2:completion");
  if (isCompletion && process.env.FAKE_FAIL_COMMENT_ONCE && !existsSync(process.env.FAKE_FAIL_COMMENT_ONCE)) {
    writeFileSync(process.env.FAKE_FAIL_COMMENT_ONCE, "failed\\n");
    process.exitCode = 1;
  } else {
    current.comments.push({ body });
    if (isCompletion && process.env.FAKE_LEAVE_FRONTIER_AFTER_COMMENT) current.labels = [];
    mutate("comment", current.number);
    save();
  }
} else if (args[0] === "issue" && args[1] === "close") {
  const current = issue();
  if (process.env.FAKE_FAIL_CLOSE_ONCE && !existsSync(process.env.FAKE_FAIL_CLOSE_ONCE)) {
    writeFileSync(process.env.FAKE_FAIL_CLOSE_ONCE, "failed\\n");
    process.exitCode = 1;
  } else {
    current.state = "CLOSED";
    mutate("close", current.number);
    save();
  }
} else {
  process.stderr.write("unexpected fake gh arguments: " + JSON.stringify(args) + "\\n");
  process.exitCode = 2;
}
`,
	);
	await chmod(fakeGitHub, 0o755);

	assert.equal((await run("git", ["init", "-q"], { cwd: repository })).code, 0);
	assert.equal(
		(
			await run("git", ["config", "user.name", "Loop Test"], {
				cwd: repository,
			})
		).code,
		0,
	);
	assert.equal(
		(
			await run("git", ["config", "user.email", "loop@example.test"], {
				cwd: repository,
			})
		).code,
		0,
	);
	assert.equal((await run("git", ["add", "."], { cwd: repository })).code, 0);
	assert.equal(
		(await run("git", ["commit", "-qm", "Initial"], { cwd: repository })).code,
		0,
	);

	return {
		base,
		repository,
		installedLoopScript,
		stateFile,
		mutationsFile,
		rpcCallsFile,
		piArgsFile,
		promptsFile,
		terminatingRpc,
		env: {
			...process.env,
			PI_BIN: fakePi,
			RPC_STREAM_BIN: join(packageRoot, "pi-rpc-stream.mjs"),
			GH_BIN: fakeGitHub,
			JQ_BIN: "jq",
			START_AT_ISSUE: String(issueNumbers[0]),
			STOP_AFTER_ISSUE: String(issueNumbers.at(-1)),
			RALPH_VERIFY_COMMAND: "true",
			FAKE_GH_STATE: stateFile,
			FAKE_MUTATIONS: mutationsFile,
			FAKE_RPC_CALLS: rpcCallsFile,
			FAKE_PI_ARGS: piArgsFile,
			FAKE_PROMPTS: promptsFile,
		},
	};
}

async function runLoop(harness, env = {}) {
	return run("bash", [harness.installedLoopScript], {
		cwd: harness.repository,
		env: { ...harness.env, ...env },
	});
}

async function readLines(path) {
	try {
		return (await readFile(path, "utf8")).trim().split("\n").filter(Boolean);
	} catch (error) {
		if (error.code === "ENOENT") return [];
		throw error;
	}
}

async function commitFile(repository, path, contents, message) {
	await writeFile(join(repository, path), contents);
	assert.equal((await run("git", ["add", path], { cwd: repository })).code, 0);
	assert.equal(
		(await run("git", ["commit", "-qm", message], { cwd: repository })).code,
		0,
	);
}

test("verified tickets close once and advance the configured issue range", {
	timeout: 60_000,
}, async () => {
	const harness = await createHarness();
	try {
		const firstRun = await runLoop(harness);
		assert.deepEqual(
			{ code: firstRun.code, signal: firstRun.signal },
			{ code: 0, signal: null },
			firstRun.stderr,
		);
		assert.deepEqual((await readLines(harness.mutationsFile)).map(JSON.parse), [
			{ operation: "assign", number: 2 },
			{ operation: "add-label", number: 2 },
			{ operation: "comment", number: 2 },
			{ operation: "comment", number: 2 },
			{ operation: "remove-label", number: 2 },
			{ operation: "remove-label", number: 2 },
			{ operation: "unassign", number: 2 },
			{ operation: "close", number: 2 },
			{ operation: "assign", number: 3 },
			{ operation: "add-label", number: 3 },
			{ operation: "comment", number: 3 },
			{ operation: "comment", number: 3 },
			{ operation: "remove-label", number: 3 },
			{ operation: "remove-label", number: 3 },
			{ operation: "unassign", number: 3 },
			{ operation: "close", number: 3 },
		]);
		const state = JSON.parse(await readFile(harness.stateFile, "utf8"));
		assert.deepEqual(state.issues[2].labels, []);
		assert.deepEqual(state.issues[3].labels, []);
		assert.deepEqual(await readLines(harness.rpcCallsFile), ["2", "3"]);
		const firstPiArgs = JSON.parse((await readLines(harness.piArgsFile))[0]);
		assert.equal(firstPiArgs.includes("--immediate-format"), true);
		for (const skill of ["implement", "tdd", "code-review"]) {
			assert.equal(
				firstPiArgs.includes(
					join(packageRoot, "skills-main", "skills", "engineering", skill),
				),
				true,
			);
		}
		const firstPrompt = JSON.parse((await readLines(harness.promptsFile))[0]);
		assert.match(firstPrompt, /Parent specification \(read-only context\)/u);
		assert.match(firstPrompt, /Read-only parent context/u);
		assert.match(firstPrompt, /Other linked issues \(read-only summaries\)/u);

		const retry = await runLoop(harness);
		assert.deepEqual(
			{ code: retry.code, signal: retry.signal },
			{ code: 0, signal: null },
			retry.stderr,
		);
		assert.equal((await readLines(harness.mutationsFile)).length, 16);
		assert.deepEqual(await readLines(harness.rpcCallsFile), ["2", "3"]);
	} finally {
		await rm(harness.base, { recursive: true, force: true });
	}
});

for (const [name, env] of [
	[
		"RPC settlement without completion evidence",
		{ FAKE_RPC_MODE: "settle-only" },
	],
	["a missing result commit", { FAKE_RPC_MODE: "missing-commit" }],
	["a dirty result worktree", { FAKE_RPC_MODE: "dirty-worktree" }],
	["a malformed completion report", { FAKE_RPC_MODE: "malformed-report" }],
	["a failed external verification gate", { RALPH_VERIFY_COMMAND: "false" }],
	[
		"a verification gate exceeding its output limit",
		{ RALPH_VERIFY_COMMAND: "yes output", RALPH_COMMAND_OUTPUT_KIB: "4" },
	],
	["an exceeded token budget", { RALPH_MAX_TOKENS: "50" }],
	[
		"an exceeded Pi time limit",
		{ FAKE_RPC_MODE: "hang", RALPH_PI_TIMEOUT_SECONDS: "1" },
	],
]) {
	test(`${name} never closes the issue`, { timeout: 20_000 }, async () => {
		const harness = await createHarness([2]);
		try {
			const result = await runLoop(harness, env);
			assert.notEqual(result.code, 0, result.stderr);
			assert.equal(
				(await readLines(harness.mutationsFile)).some(
					(line) => JSON.parse(line).operation === "close",
				),
				false,
			);
			const state = JSON.parse(await readFile(harness.stateFile, "utf8"));
			assert.deepEqual(state.issues[2].labels, [{ name: "ready-for-human" }]);
			assert.deepEqual(state.issues[2].assignees, []);
		} finally {
			await rm(harness.base, { recursive: true, force: true });
		}
	});
}

test("missing lifecycle labels are created during preflight", {
	timeout: 20_000,
}, async () => {
	const harness = await createHarness([2]);
	try {
		const state = JSON.parse(await readFile(harness.stateFile, "utf8"));
		state.repositoryLabels = ["ready-for-agent"];
		await writeFile(harness.stateFile, `${JSON.stringify(state)}\n`);

		const result = await runLoop(harness);
		assert.equal(result.code, 0, result.stderr);
		const mutations = (await readLines(harness.mutationsFile)).map(JSON.parse);
		assert.deepEqual(mutations.slice(0, 2), [
			{ operation: "create-label", name: "ready-for-human" },
			{ operation: "create-label", name: "in-progress" },
		]);
		const finalState = JSON.parse(await readFile(harness.stateFile, "utf8"));
		assert.deepEqual(finalState.repositoryLabels, [
			"ready-for-agent",
			"ready-for-human",
			"in-progress",
		]);
	} finally {
		await rm(harness.base, { recursive: true, force: true });
	}
});

test("concurrent lifecycle label creation is an idempotent preflight no-op", {
	timeout: 20_000,
}, async () => {
	const harness = await createHarness([2]);
	try {
		const state = JSON.parse(await readFile(harness.stateFile, "utf8"));
		state.repositoryLabels = ["ready-for-agent", "in-progress"];
		await writeFile(harness.stateFile, `${JSON.stringify(state)}\n`);

		const result = await runLoop(harness, { FAKE_LABEL_CREATE_RACE: "1" });
		assert.equal(result.code, 0, result.stderr);
		assert.equal(
			(await readLines(harness.mutationsFile)).some(
				(line) => JSON.parse(line).operation === "create-label",
			),
			false,
		);
	} finally {
		await rm(harness.base, { recursive: true, force: true });
	}
});

test("unrecoverable lifecycle label creation stops before claim", {
	timeout: 20_000,
}, async () => {
	const harness = await createHarness([2]);
	try {
		const state = JSON.parse(await readFile(harness.stateFile, "utf8"));
		state.repositoryLabels = ["ready-for-agent", "in-progress"];
		await writeFile(harness.stateFile, `${JSON.stringify(state)}\n`);

		const result = await runLoop(harness, { FAKE_FAIL_LABEL_CREATE: "1" });
		assert.notEqual(result.code, 0, result.stderr);
		assert.match(
			result.stderr,
			/failed to create required tracker label: ready-for-human/u,
		);
		assert.deepEqual(await readLines(harness.mutationsFile), []);
		assert.deepEqual(await readLines(harness.rpcCallsFile), []);
	} finally {
		await rm(harness.base, { recursive: true, force: true });
	}
});

test("explicit termination moves the claimed issue to human-ready", {
	timeout: 20_000,
}, async () => {
	const harness = await createHarness([2]);
	try {
		const result = await runLoop(harness, {
			RPC_STREAM_BIN: harness.terminatingRpc,
		});
		assert.notEqual(result.code, 0, result.stderr);
		const state = JSON.parse(await readFile(harness.stateFile, "utf8"));
		assert.equal(state.issues[2].state, "OPEN");
		assert.deepEqual(state.issues[2].labels, [{ name: "ready-for-human" }]);
		assert.deepEqual(state.issues[2].assignees, []);
		assert.equal(
			(await readLines(harness.mutationsFile)).some(
				(line) => JSON.parse(line).operation === "close",
			),
			false,
		);
	} finally {
		await rm(harness.base, { recursive: true, force: true });
	}
});

test("an explicit retry archives an incomplete Pi attempt and runs quality gates", {
	timeout: 30_000,
}, async () => {
	const harness = await createHarness([2]);
	const verificationMarker = join(harness.base, "verification-ran.txt");
	try {
		const firstRun = await runLoop(harness, { FAKE_RPC_MODE: "settle-only" });
		assert.notEqual(firstRun.code, 0, firstRun.stderr);

		const retry = await runLoop(harness, {
			RALPH_VERIFY_COMMAND: `printf verified > ${JSON.stringify(verificationMarker)}`,
		});
		assert.equal(retry.code, 0, retry.stderr);
		const mutations = (await readLines(harness.mutationsFile)).map(JSON.parse);
		assert.equal(
			mutations.filter(({ operation }) => operation === "comment").length,
			2,
		);
		assert.deepEqual(await readLines(harness.rpcCallsFile), ["2", "2"]);
		assert.equal(
			mutations.filter(({ operation }) => operation === "close").length,
			1,
		);
		assert.deepEqual(await readLines(verificationMarker), ["verified"]);
		assert.notEqual(
			(
				await readFile(
					join(
						harness.repository,
						".ralph",
						"runs",
						"issue-2",
						"attempts",
						"attempt-1",
						"rpc.jsonl",
					),
					"utf8",
				)
			).length,
			0,
		);
	} finally {
		await rm(harness.base, { recursive: true, force: true });
	}
});

for (const operation of ["COMMENT", "CLOSE"]) {
	test(`${operation.toLowerCase()} failure retries tracker completion without rerunning Pi`, {
		timeout: 20_000,
	}, async () => {
		const harness = await createHarness([2]);
		const failureMarker = join(
			harness.base,
			`${operation.toLowerCase()}-failed`,
		);
		const failureEnv = { [`FAKE_FAIL_${operation}_ONCE`]: failureMarker };
		try {
			const firstRun = await runLoop(harness, failureEnv);
			assert.notEqual(firstRun.code, 0, firstRun.stderr);
			assert.deepEqual(await readLines(harness.rpcCallsFile), ["2"]);

			const retry = await runLoop(harness, failureEnv);
			assert.equal(retry.code, 0, retry.stderr);
			assert.deepEqual(await readLines(harness.rpcCallsFile), ["2"]);
			const mutations = (await readLines(harness.mutationsFile)).map(
				JSON.parse,
			);
			assert.equal(
				mutations.filter(({ operation: mutation }) => mutation === "comment")
					.length,
				2,
			);
			assert.equal(
				mutations.filter(({ operation: mutation }) => mutation === "close")
					.length,
				1,
			);
		} finally {
			await rm(harness.base, { recursive: true, force: true });
		}
	});
}

test("validated RPC evidence recovers without rerunning Pi", {
	timeout: 20_000,
}, async () => {
	const harness = await createHarness([2]);
	const evidenceFile = join(
		harness.repository,
		".ralph",
		"runs",
		"issue-2",
		"completion-evidence.json",
	);
	try {
		const firstRun = await runLoop(harness, { RALPH_VERIFY_COMMAND: "false" });
		assert.notEqual(firstRun.code, 0, firstRun.stderr);
		await rm(evidenceFile);

		const retry = await runLoop(harness);
		assert.equal(retry.code, 0, retry.stderr);
		assert.deepEqual(await readLines(harness.rpcCallsFile), ["2"]);
		assert.equal(
			(await readLines(harness.mutationsFile))
				.map(JSON.parse)
				.filter(({ operation }) => operation === "close").length,
			1,
		);
	} finally {
		await rm(harness.base, { recursive: true, force: true });
	}
});

test("validated RPC evidence recovers after later commits without rerunning Pi", {
	timeout: 20_000,
}, async () => {
	const harness = await createHarness([2]);
	const evidenceFile = join(
		harness.repository,
		".ralph",
		"runs",
		"issue-2",
		"completion-evidence.json",
	);
	try {
		const firstRun = await runLoop(harness, { RALPH_VERIFY_COMMAND: "false" });
		assert.notEqual(firstRun.code, 0, firstRun.stderr);
		await rm(evidenceFile);
		await commitFile(
			harness.repository,
			"later-ticket.txt",
			"later change\n",
			"Complete later ticket",
		);

		const retry = await runLoop(harness);
		assert.equal(retry.code, 0, retry.stderr);
		assert.deepEqual(await readLines(harness.rpcCallsFile), ["2"]);
		assert.equal(
			(await readLines(harness.mutationsFile))
				.map(JSON.parse)
				.filter(({ operation }) => operation === "close").length,
			1,
		);
	} finally {
		await rm(harness.base, { recursive: true, force: true });
	}
});

test("persisted evidence recovers after later commits and advances the range", {
	timeout: 30_000,
}, async () => {
	const harness = await createHarness([2, 3]);
	try {
		const firstRun = await runLoop(harness, { RALPH_VERIFY_COMMAND: "false" });
		assert.notEqual(firstRun.code, 0, firstRun.stderr);
		await commitFile(
			harness.repository,
			"later-ticket.txt",
			"later change\n",
			"Complete later ticket",
		);

		const retry = await runLoop(harness);
		assert.equal(retry.code, 0, retry.stderr);
		assert.deepEqual(await readLines(harness.rpcCallsFile), ["2", "3"]);
		assert.deepEqual(
			(await readLines(harness.mutationsFile))
				.map(JSON.parse)
				.filter(({ operation }) => operation === "close")
				.map(({ number }) => number),
			[2, 3],
		);
	} finally {
		await rm(harness.base, { recursive: true, force: true });
	}
});

test("pending publication refuses to publish later commits during recovery", {
	timeout: 20_000,
}, async () => {
	const harness = await createHarness([2]);
	const publicationSideEffect = join(
		harness.repository,
		"forbidden-publication.txt",
	);
	try {
		const firstRun = await runLoop(harness, { RALPH_PUBLISH_COMMAND: "false" });
		assert.notEqual(firstRun.code, 0, firstRun.stderr);
		await commitFile(
			harness.repository,
			"later-ticket.txt",
			"later change\n",
			"Complete later ticket",
		);

		const retry = await runLoop(harness, {
			RALPH_PUBLISH_COMMAND: "printf published > forbidden-publication.txt",
		});
		assert.notEqual(retry.code, 0, retry.stderr);
		assert.match(
			retry.stderr,
			/refusing to publish issue #2 after later commits/u,
		);
		assert.deepEqual(await readLines(publicationSideEffect), []);
	} finally {
		await rm(harness.base, { recursive: true, force: true });
	}
});

test("verification failure resumes without rerunning Pi", {
	timeout: 20_000,
}, async () => {
	const harness = await createHarness([2]);
	try {
		const firstRun = await runLoop(harness, { RALPH_VERIFY_COMMAND: "false" });
		assert.notEqual(firstRun.code, 0, firstRun.stderr);
		assert.deepEqual(await readLines(harness.rpcCallsFile), ["2"]);

		const retry = await runLoop(harness, { RALPH_VERIFY_COMMAND: "true" });
		assert.equal(retry.code, 0, retry.stderr);
		assert.deepEqual(await readLines(harness.rpcCallsFile), ["2"]);
		assert.equal(
			(await readLines(harness.mutationsFile))
				.map(JSON.parse)
				.filter(({ operation }) => operation === "close").length,
			1,
		);
	} finally {
		await rm(harness.base, { recursive: true, force: true });
	}
});

test("publication failure resumes after verification without rerunning Pi", {
	timeout: 20_000,
}, async () => {
	const harness = await createHarness([2]);
	try {
		const firstRun = await runLoop(harness, { RALPH_PUBLISH_COMMAND: "false" });
		assert.notEqual(firstRun.code, 0, firstRun.stderr);
		assert.deepEqual(await readLines(harness.rpcCallsFile), ["2"]);

		const retry = await runLoop(harness, { RALPH_PUBLISH_COMMAND: "true" });
		assert.equal(retry.code, 0, retry.stderr);
		assert.deepEqual(await readLines(harness.rpcCallsFile), ["2"]);
		assert.deepEqual((await readLines(harness.mutationsFile)).map(JSON.parse), [
			{ operation: "assign", number: 2 },
			{ operation: "add-label", number: 2 },
			{ operation: "comment", number: 2 },
			{ operation: "add-label", number: 2 },
			{ operation: "remove-label", number: 2 },
			{ operation: "remove-label", number: 2 },
			{ operation: "unassign", number: 2 },
			{ operation: "comment", number: 2 },
			{ operation: "remove-label", number: 2 },
			{ operation: "close", number: 2 },
		]);
	} finally {
		await rm(harness.base, { recursive: true, force: true });
	}
});

test("the issue is rechecked immediately before close", {
	timeout: 20_000,
}, async () => {
	const harness = await createHarness([2]);
	try {
		const result = await runLoop(harness, {
			FAKE_LEAVE_FRONTIER_AFTER_COMMENT: "1",
		});
		assert.notEqual(result.code, 0, result.stderr);
		assert.deepEqual((await readLines(harness.mutationsFile)).map(JSON.parse), [
			{ operation: "assign", number: 2 },
			{ operation: "add-label", number: 2 },
			{ operation: "comment", number: 2 },
			{ operation: "comment", number: 2 },
			{ operation: "add-label", number: 2 },
			{ operation: "unassign", number: 2 },
		]);
	} finally {
		await rm(harness.base, { recursive: true, force: true });
	}
});

test("publication cannot close an issue after dirtying the worktree", {
	timeout: 20_000,
}, async () => {
	const harness = await createHarness([2]);
	try {
		const result = await runLoop(harness, {
			RALPH_PUBLISH_COMMAND: "printf dirty > publication-dirty.txt",
		});
		assert.notEqual(result.code, 0, result.stderr);
		assert.equal(
			(await readLines(harness.mutationsFile)).some(
				(line) => JSON.parse(line).operation === "close",
			),
			false,
		);
	} finally {
		await rm(harness.base, { recursive: true, force: true });
	}
});

test("a non-exclusive GitHub assignment stops before Pi", {
	timeout: 20_000,
}, async () => {
	const harness = await createHarness([2]);
	try {
		const result = await runLoop(harness, { FAKE_ADD_RIVAL_ASSIGNEE: "1" });
		assert.notEqual(result.code, 0, result.stderr);
		assert.match(result.stderr, /claim is not exclusive/u);
		assert.deepEqual(await readLines(harness.rpcCallsFile), []);
	} finally {
		await rm(harness.base, { recursive: true, force: true });
	}
});

test("a stale same-checkout Campaign lock is reclaimed", {
	timeout: 20_000,
}, async () => {
	const harness = await createHarness([2]);
	const lockDirectory = join(harness.repository, ".git", "ralph-loop-v2.lock");
	try {
		await mkdir(lockDirectory);
		await writeFile(join(lockDirectory, "owner"), "99999999\n");
		const result = await runLoop(harness);
		assert.equal(result.code, 0, result.stderr);
		assert.deepEqual(await readLines(harness.rpcCallsFile), ["2"]);
	} finally {
		await rm(harness.base, { recursive: true, force: true });
	}
});

test("a same-checkout Campaign lock prevents a second loop", {
	timeout: 20_000,
}, async () => {
	const harness = await createHarness([2]);
	const lockDirectory = join(harness.repository, ".git", "ralph-loop-v2.lock");
	try {
		await mkdir(lockDirectory);
		await writeFile(join(lockDirectory, "owner"), "another-process\n");
		const result = await runLoop(harness);
		assert.notEqual(result.code, 0, result.stderr);
		assert.match(result.stderr, /another loop-v2 Campaign owns this checkout/u);
		assert.deepEqual(await readLines(harness.rpcCallsFile), []);
	} finally {
		await rm(harness.base, { recursive: true, force: true });
	}
});
