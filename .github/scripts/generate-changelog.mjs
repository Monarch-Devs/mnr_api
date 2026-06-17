/**
*   Generates a plain-text changelog from Conventional Commits between two git refs.
*   Prints plain text to stdout, grouped by type:
*       
*   Features:
*       - description (hash)
*   Fixes:
*       - description (hash)
*   Performance:
*       - description (hash)
*   Other:
*       - description (hash)
*
*   IMPORTANT: commits without a recognizable Conventional Commit header will appear
*   under "Other" so nothing silently disappears from the release notes.
**/

import { execFileSync } from 'node:child_process';

const HEADER_RE = /^(!)?(\w+)(?:\([^)]*\))?:\s*(.+)/;
const GROUP_LABELS = {
  feat: 'Features',
  fix: 'Fixes',
  perf: 'Performance',
};

const GROUP_ORDER = ['feat', 'fix', 'perf', 'other'];

function parseArgs(argv) {
  const [fromRef, toRef] = argv;
  if (!fromRef || !toRef) {
    process.stderr.write('Usage: generate-changelog.mjs <fromRef> <toRef>\n');
    process.exit(2);
  }
  return { fromRef, toRef };
}

function readCommits(fromRef, toRef) {
  const SEP = '\u0001COMMIT\u0001';
  const FMT = `%h%x02%s%x02%b${SEP}`;

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
    })
    .reverse();
}

function classify({ header }) {
  const match = HEADER_RE.exec(header);

  if (!match) {
    return {
      group: 'other',
      description: header,
      breaking: false
    };
  }

  const [, bang, type, description] = match;
  const normalizedType = type.toLowerCase();
  const group = GROUP_LABELS[normalizedType] ? normalizedType : 'other';

  return {
    group,
    description,
    breaking: Boolean(bang)
  };
}

function buildChangelog(commits) {
  const grouped = { feat: [], fix: [], perf: [], other: [] };

  for (const commit of commits) {
    const { group, description, breaking } = classify(commit);
    const line = `- ${breaking ? '[BREAKING] ' : ''}${description} (${commit.hash})`;
    grouped[group].push(line);
  }

  const sections = [];
  for (const key of GROUP_ORDER) {
    if (grouped[key].length === 0) continue;
    const label = key === 'other' ? 'Other' : GROUP_LABELS[key];
    sections.push(`${label}:\n${grouped[key].join('\n')}`);
  }

  return sections.length > 0 ? sections.join('\n\n') : 'No notable changes.';
}

function main() {
  const { fromRef, toRef } = parseArgs(process.argv.slice(2));
  const commits = readCommits(fromRef, toRef);
  process.stdout.write(buildChangelog(commits) + '\n');
}

main();