#!/usr/bin/env node
/**
 * Structural validation for the roblox-dev plugin.
 * Run: node scripts/validate.mjs
 * Exits non-zero on any failure. No dependencies.
 */
import { readFileSync, readdirSync, existsSync, statSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const errors = [];
const ok = (msg) => console.log(`  ✓ ${msg}`);
const fail = (msg) => {
  errors.push(msg);
  console.error(`  ✗ ${msg}`);
};

// --- plugin.json -----------------------------------------------------------
console.log("plugin.json");
let plugin;
try {
  plugin = JSON.parse(readFileSync(join(root, ".claude-plugin/plugin.json"), "utf8"));
  ok("parses as JSON");
  for (const field of ["name", "description", "version"]) {
    if (typeof plugin[field] === "string" && plugin[field].length > 0) ok(`has ${field}`);
    else fail(`missing or empty field: ${field}`);
  }
  if (!/^\d+\.\d+\.\d+$/.test(plugin.version ?? "")) fail("version is not semver");
  else ok(`version ${plugin.version} is semver`);
} catch (e) {
  fail(`plugin.json unreadable: ${e.message}`);
}

// --- marketplace.json ------------------------------------------------------
console.log("marketplace.json");
try {
  const marketplace = JSON.parse(
    readFileSync(join(root, ".claude-plugin/marketplace.json"), "utf8"),
  );
  ok("parses as JSON");
  const entry = marketplace.plugins?.find((p) => p.name === plugin?.name);
  if (entry) ok(`lists plugin "${plugin.name}"`);
  else fail(`does not list plugin "${plugin?.name}"`);
} catch (e) {
  fail(`marketplace.json unreadable: ${e.message}`);
}

// --- skills ----------------------------------------------------------------
console.log("skills/");
const skillsDir = join(root, "skills");
const skillFolders = readdirSync(skillsDir).filter((f) =>
  statSync(join(skillsDir, f)).isDirectory(),
);
if (skillFolders.length === 0) fail("no skills found");
for (const folder of skillFolders) {
  const skillPath = join(skillsDir, folder, "SKILL.md");
  if (!existsSync(skillPath)) {
    fail(`${folder}: missing SKILL.md`);
    continue;
  }
  const content = readFileSync(skillPath, "utf8");
  const fm = content.match(/^---\n([\s\S]*?)\n---/);
  if (!fm) {
    fail(`${folder}: SKILL.md has no frontmatter`);
    continue;
  }
  const descMatch = fm[1].match(/^description:\s*(.+)$/m);
  if (!descMatch || descMatch[1].trim().length < 20) {
    fail(`${folder}: frontmatter description missing or too short`);
  } else if (descMatch[1].length > 1024) {
    fail(`${folder}: description exceeds 1024 characters`);
  } else {
    ok(`${folder}: SKILL.md valid (description ${descMatch[1].length} chars)`);
  }
  // Referenced local files must exist
  for (const match of content.matchAll(/\]\((references\/[^)]+)\)/g)) {
    const ref = join(skillsDir, folder, match[1]);
    if (!existsSync(ref)) fail(`${folder}: broken reference link ${match[1]}`);
    else ok(`${folder}: reference ${match[1]} exists`);
  }
}

// --- agents ----------------------------------------------------------------
console.log("agents/");
const agentsDir = join(root, "agents");
for (const file of readdirSync(agentsDir).filter((f) => f.endsWith(".md"))) {
  const content = readFileSync(join(agentsDir, file), "utf8");
  const fm = content.match(/^---\n([\s\S]*?)\n---/);
  if (!fm) fail(`${file}: no frontmatter`);
  else if (!/^name:\s*\S+/m.test(fm[1])) fail(`${file}: frontmatter missing name`);
  else if (!/^description:\s*\S+/m.test(fm[1])) fail(`${file}: frontmatter missing description`);
  else ok(`${file}: valid agent definition`);
}

// --- docs ------------------------------------------------------------------
console.log("docs");
for (const file of ["README.md", "README.es.md", "LICENSE", "CHANGELOG.md", "CONTRIBUTING.md"]) {
  if (existsSync(join(root, file))) ok(`${file} present`);
  else fail(`${file} missing`);
}

// ---------------------------------------------------------------------------
if (errors.length > 0) {
  console.error(`\n${errors.length} validation error(s).`);
  process.exit(1);
}
console.log("\nAll checks passed.");
