import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { isExpectedRemote, pushCommittedChanges, solarCredential } from './push_commits.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../..');
const stateFile = path.join(root, '.git-sync', 'pending-pr.json');
const identity = ['-c', 'user.name=Solar', '-c', 'user.email=338115045+Solar-owo@users.noreply.github.com'];

// Only repository code, build definitions and documentation are eligible.
export function eligible(file) {
  if (/(^|\/)(?:\.env(?:\..*)?|.*credentials.*|.*service.account.*|.*\.sqlite(?:3)?|.*\.db|.*\.log|.*\.pem|.*\.key|.*\.p12|.*\.jks|.*\.keystore)$/i.test(file)) return false;
  if (/(^|\/)(?:node_modules|build|\.dart_tool|\.git|\.git-sync|\.firebase-data-backups|\.aws|\.codex|\.agents|local|exports|backups)(\/|$)/i.test(file)) return false;
  if (/(^|\/)(?:local\.properties|key\.properties|.*\.local\..*)$/i.test(file)) return false;
  return ['AGENTS.md', '.gitignore'].includes(file) ||
    (/^soundboard\//.test(file) && /\.(?:dart|kt|kts|java|swift|m|h|mm|c|cc|cpp|html|css|js|mjs|ts|json|yaml|yml|lock|md|rules|xml|plist|pbxproj|xcconfig|gradle|properties|ps1|sh|txt|png|jpg|jpeg|svg|ico|webp|woff2?|ttf|mp3|wav|ogg)$/i.test(file));
}

function git(args, input) {
  try {
    return execFileSync('git', args, { cwd: root, encoding: 'utf8', windowsHide: true, input,
      timeout: 120000, stdio: ['pipe', 'pipe', 'pipe'],
      env: { ...process.env, GIT_TERMINAL_PROMPT: '0', GCM_INTERACTIVE: 'Never' } }).trimEnd();
  } catch { throw new Error(`Git ${args.find(a => !a.startsWith('-'))} failed; inspect the repository. No force-push or automatic merge was attempted.`); }
}

export async function sync(runGit = git, request = fetch, state = {
  pending: () => fs.existsSync(stateFile),
  save: () => { fs.mkdirSync(path.dirname(stateFile), { recursive: true }); fs.writeFileSync(stateFile, '{}\n'); },
  clear: () => { if (fs.existsSync(stateFile)) fs.unlinkSync(stateFile); },
}) {
  if (runGit(['branch', '--show-current']) !== 'D-Time') throw new Error('Hourly sync requires the checked-out branch to be D-Time.');
  if (!isExpectedRemote(runGit(['remote', 'get-url', 'origin']))) throw new Error('Unexpected origin; sync stopped.');
  const staged = runGit(['diff', '--cached', '--name-only', '-z']).split('\0').filter(Boolean);
  if (staged.some(f => !eligible(f))) throw new Error('Excluded files are staged; sync stopped without changing the index.');
  const changed = [...new Set([
    ...runGit(['diff', '--name-only', '-z', 'HEAD']).split('\0'),
    ...runGit(['ls-files', '--others', '--exclude-standard', '-z']).split('\0'),
  ].filter(f => f && eligible(f)))];
  const ahead = runGit(['rev-list', '--count', 'refs/remotes/origin/D-Time..HEAD']);
  if (!changed.length && ahead === '0' && !state.pending()) return { status: 'unchanged' };

  const token = solarCredential(runGit);
  async function api(endpoint, method = 'GET', body) {
    const response = await request(`https://api.github.com/${endpoint}`, {
      method, headers: { Authorization: `Bearer ${token}`, Accept: 'application/vnd.github+json',
        'Content-Type': 'application/json', 'User-Agent': 'SoundBoard-Solar-hourly' },
      ...(body ? { body: JSON.stringify(body) } : {}), signal: AbortSignal.timeout(60000),
    });
    if (!response.ok) throw new Error(`GitHub request failed (${response.status}); next hourly run will retry.`);
    return response.json();
  }
  const user = await api('user');
  if (user.login !== 'Solar-owo' || user.id !== 338115045) throw new Error('Saved account is not Solar-owo.');
  const repo = await api('repos/Iris9600/SoundBoard');
  if (!repo.permissions?.push) throw new Error('Solar lacks accepted write access.');
  // Do not commit over an interrupted merge, rebase or cherry-pick.
  for (const marker of ['MERGE_HEAD', 'CHERRY_PICK_HEAD', 'REVERT_HEAD', 'rebase-merge', 'rebase-apply']) {
    const markerPath = runGit(['rev-parse', '--git-path', marker]);
    if (fs.existsSync(path.resolve(root, markerPath))) throw new Error('An unfinished Git operation needs owner attention.');
  }
  state.save();
  if (changed.length) {
    for (let i = 0; i < changed.length; i += 100) runGit(['--literal-pathspecs', 'add', '-A', '--', ...changed.slice(i, i + 100)]);
    if (runGit(['diff', '--cached', '--name-only', '-z'])) {
      runGit([...identity, 'commit', '-m', `Update SoundBoard (${new Date().toISOString()})`]);
    }
  }
  const result = await pushCommittedChanges(runGit, request);
  const prs = await api('repos/Iris9600/SoundBoard/pulls?state=open&base=main&head=Iris9600:D-Time');
  let pr = prs[0];
  if (!pr) {
    const comparison = await api('repos/Iris9600/SoundBoard/compare/main...D-Time');
    if (comparison.ahead_by > 0) pr = await api('repos/Iris9600/SoundBoard/pulls', 'POST', {
      title: 'SoundBoard updates from D-Time', head: 'D-Time', base: 'main',
      body: 'Hourly Solar sync of repository code changes. Owner review and merge required. Automated sync does not run Flutter checks; inspect changes and run relevant checks before merging.',
    });
  }
  state.clear();
  return { ...result, files: changed.length, ...(pr ? { pullRequest: pr.html_url } : {}) };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  fs.mkdirSync(path.dirname(stateFile), { recursive: true });
  try {
    const result = await sync();
    if (result.status !== 'unchanged' || result.pullRequest) {
      console.log(JSON.stringify(result));
      fs.appendFileSync(path.join(root, '.git-sync', 'push.log'), `${new Date().toISOString()} ${JSON.stringify(result)}\n`);
    }
  } catch (error) {
    console.error(error.message);
    fs.appendFileSync(path.join(root, '.git-sync', 'push.log'), `${new Date().toISOString()} ERROR ${error.message}\n`);
    process.exitCode = 1;
  }
}
