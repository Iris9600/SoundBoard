import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const ACCOUNT = 'Solar-owo';
const REPOSITORY = 'Iris9600/SoundBoard';
const BRANCH = 'D-Time';
const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../..');
const credentialArgs = ['-c', `credential.https://github.com.username=${ACCOUNT}`, '-c', 'credential.interactive=never'];

export function isExpectedRemote(remote) {
  try {
    const url = new URL(remote);
    return url.protocol === 'https:' && url.hostname === 'github.com' && !url.password &&
      (!url.username || url.username === ACCOUNT) && !url.search && !url.hash &&
      url.pathname.replace(/\.git$/i, '').replace(/\/$/, '').toLowerCase() === `/${REPOSITORY.toLowerCase()}`;
  } catch { return false; }
}

function git(args, input) {
  try {
    return execFileSync('git', args, {
      cwd: repoRoot, encoding: 'utf8', input, timeout: 120_000,
      windowsHide: true, stdio: ['pipe', 'pipe', 'pipe'],
      env: { ...process.env, GIT_TERMINAL_PROMPT: '0', GCM_INTERACTIVE: 'Never' },
    }).trim();
  } catch {
    // Native errors may include credential output. Never print them.
    throw new Error('Git operation failed. Check Solar login, network access and whether D-Time needs an explicit rebase or merge. No force-push was attempted.');
  }
}

export function solarCredential(runGit = git) {
  const filled = runGit([...credentialArgs, 'credential', 'fill'],
    `protocol=https\nhost=github.com\npath=${REPOSITORY}.git\nusername=${ACCOUNT}\n\n`);
  const values = Object.fromEntries(filled.split(/\r?\n/).filter(Boolean).map(line => {
    const split = line.indexOf('=');
    return [line.slice(0, split), line.slice(split + 1)];
  }));
  if (!values.password) throw new Error('Solar has no saved GitHub credential. Sign in through Git Credential Manager.');
  return values.password;
}

export async function pushCommittedChanges(runGit = git, request = fetch) {
  const remote = runGit(['remote', 'get-url', 'origin']);
  if (!isExpectedRemote(remote)) throw new Error('Refusing to push: origin is not Iris9600/SoundBoard.');
  const head = runGit(['rev-parse', `refs/heads/${BRANCH}`]);
  if (!/^[a-f0-9]{40,64}$/.test(head)) throw new Error('D-Time does not have a valid commit.');
  const token = solarCredential(runGit);
  async function api(endpoint) {
    const response = await request(`https://api.github.com/${endpoint}`, {
      headers: { Authorization: `Bearer ${token}`, Accept: 'application/vnd.github+json', 'User-Agent': 'SoundBoard-Solar-sync' },
      signal: AbortSignal.timeout(60_000),
    });
    if (!response.ok) throw new Error(`GitHub verification failed (${response.status}). No push attempted.`);
    return response.json();
  }
  const user = await api('user');
  if (user.login !== ACCOUNT || user.id !== 338115045) throw new Error('Saved GitHub credential is not Solar-owo. No push attempted.');
  const repository = await api(`repos/${REPOSITORY}`);
  if (!repository.permissions?.push) throw new Error('Solar does not have accepted write access to Iris9600/SoundBoard.');
  const remoteHead = runGit([...credentialArgs, 'ls-remote', '--heads', 'origin', `refs/heads/${BRANCH}`]);
  if (remoteHead.split(/\s+/)[0] === head) return { status: 'unchanged', account: ACCOUNT, repository: REPOSITORY, branch: BRANCH, commit: head };
  // Push only an existing committed branch. Never add, commit, pull, merge or force.
  runGit([...credentialArgs, 'push', '--set-upstream', 'origin', `refs/heads/${BRANCH}:refs/heads/${BRANCH}`]);
  return { status: 'pushed', account: ACCOUNT, repository: REPOSITORY, branch: BRANCH, commit: head };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const stateRoot = path.join(repoRoot, '.git-sync');
  fs.mkdirSync(stateRoot, { recursive: true });
  try {
    const result = await pushCommittedChanges();
    console.log(JSON.stringify(result, null, 2));
    fs.appendFileSync(path.join(stateRoot, 'push.log'), `${new Date().toISOString()} ${JSON.stringify(result)}\n`);
  } catch (error) {
    console.error(error.message);
    fs.appendFileSync(path.join(stateRoot, 'push.log'), `${new Date().toISOString()} ERROR ${error.message}\n`);
    process.exitCode = 1;
  }
}
