/**
*   BUMP CALCULATOR
* 
*   Semantic Versioning bump based on Conventional Commits.
*
*   Rules:
*   - "feat"                -> minor
*   - "fix" / "perf"        -> patch
*   - "!" before the type   -> major      (e.g. "!feat:", "!fix(scope):")
*
*   IMPORTANT: when the bump is a major it auto-triggers the creation of
*   a new tag and tag creation triggers the release
**/

import { execFileSync } from 'node:child_process';

const PRECEDENCE = { none: 0, patch: 1, minor: 2, major: 3 };
const HEADER_RE = /^(!)?(\w+)(?:\([^)]*\))?:\s*.+/;

function parseArgs(argv) {
  const [fromRef, toRef, currentVersion] = argv;
  if (!fromRef || !toRef || !currentVersion) {
    process.stderr.write('Usage: compute-bump.mjs <fromRef> <toRef> <currentVersion>\n');
    process.exit(2);
  }
  if (!/^\d+\.\d+\.\d+$/.test(currentVersion)) {
    process.stderr.write(`Invalid currentVersion "${currentVersion}", expected X.Y.Z\n`);
    process.exit(2);
  }
  return { fromRef, toRef, currentVersion };
}

function readCommits(fromRef, toRef) {
  const SEP = '\u0001COMMIT\u0001';
  const FMT = `%H%x02%s%x02%b${SEP}`;

  let raw;
  try {
    raw = execFileSync(
      'git',
      ['log', `${fromRef}..${toRef}`, `--pretty=format:${FMT}`, '--no-merges'],
      { encoding: 'utf8', maxBuffer: 1024 * 1024 * 64 }
    );
  } catch (err) {
    process.stderr.write(`git log failed: ${err.message}\n`);
    process.exit(1);
  }

  return raw
    .split(SEP)
    .map((chunk) => chunk.trim())
    .filter(Boolean)
    .map((chunk) => {
      const [hash, header, body] = chunk.split('\x02');
      return { hash, header: (header || '').trim(), body: (body || '').trim() };
    });
}

function classifyCommit({ header, body }) {
  const match = HEADER_RE.exec(header);
  if (!match) return 'none';

  const [, bang, type] = match;
  const normalizedType = type.toLowerCase();

  if (Boolean(bang)) return 'major';
  if (normalizedType === 'feat') return 'minor';
  if (normalizedType === 'fix' || normalizedType === 'perf') return 'patch';

  return 'none';
}

function highestBump(commits) {
  let best = 'none';
  for (const commit of commits) {
    const level = classifyCommit(commit);
    if (PRECEDENCE[level] > PRECEDENCE[best]) best = level;
  }
  return best;
}

function applyBump(version, bump) {
  if (bump === 'none') return version;

  const [major, minor, patch] = version.split('.').map(Number);

  if (bump === 'major') return `${major + 1}.0.0`;
  if (bump === 'minor') return `${major}.${minor + 1}.0`;
  return `${major}.${minor}.${patch + 1}`;
}

function main() {
  const { fromRef, toRef, currentVersion } = parseArgs(process.argv.slice(2));
  const commits = readCommits(fromRef, toRef);
  const bump = highestBump(commits);
  const version = applyBump(currentVersion, bump);
  const shouldTag = bump === 'major';

  process.stdout.write(JSON.stringify({ bump, version, shouldTag }) + '\n');
}

main();