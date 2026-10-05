import test from 'node:test';
import assert from 'node:assert/strict';
import { isExpectedRemote, pushCommittedChanges } from './push_commits.mjs';

const commit = 'a'.repeat(40);
function fixture(options = {}) {
  const commands = [];
  const runGit = args => {
    commands.push(args);
    if (args[0] === 'remote') return options.remote ?? 'https://github.com/Iris9600/SoundBoard.git';
    if (args[0] === 'rev-parse') return commit;
    if (args.includes('credential')) return 'username=Solar-owo\npassword=TEST-CREDENTIAL\n';
    if (args.includes('ls-remote')) return options.unchanged ? `${commit}\trefs/heads/D-Time` : '';
    if (args.includes('push')) {
      if (options.pushFails) throw new Error('remote rejected');
      return '';
    }
    throw new Error(`Unexpected Git command: ${args.join(' ')}`);
  };
  const request = async uri => ({
    ok: true,
    json: async () => uri.endsWith('/user')
      ? { login: options.account ?? 'Solar-owo', id: options.account ? 1 : 338115045 }
      : { permissions: { push: options.writeAccess ?? true } },
  });
  return { runGit, request, commands };
}

test('only the confirmed HTTPS upstream is accepted', () => {
  assert.ok(isExpectedRemote('https://github.com/Iris9600/SoundBoard.git'));
  assert.ok(isExpectedRemote('https://Solar-owo@github.com/Iris9600/SoundBoard.git'));
  for (const bad of ['https://github.com/Solar-owo/SoundBoard.git', 'https://example.com/Iris9600/SoundBoard.git', 'https://user:secret@github.com/Iris9600/SoundBoard.git']) {
    assert.equal(isExpectedRemote(bad), false);
  }
});

test('new branch pushes committed D-Time only and never stages, commits or merges', async () => {
  const f = fixture();
  assert.equal((await pushCommittedChanges(f.runGit, f.request)).status, 'pushed');
  const push = f.commands.find(args => args.includes('push'));
  assert.equal(push.at(-1), 'refs/heads/D-Time:refs/heads/D-Time');
  assert.ok(push.includes('credential.https://github.com.username=Solar-owo'));
  assert.equal(f.commands.some(args => args.some(arg => ['add', 'commit', 'merge', '--force', '--force-with-lease'].includes(arg))), false);
});

test('unchanged remote commit is not pushed again', async () => {
  const f = fixture({ unchanged: true });
  assert.equal((await pushCommittedChanges(f.runGit, f.request)).status, 'unchanged');
  assert.equal(f.commands.some(args => args.includes('push')), false);
});

test('wrong upstream is rejected before reading credentials', async () => {
  const f = fixture({ remote: 'https://github.com/Solar-owo/SoundBoard.git' });
  await assert.rejects(pushCommittedChanges(f.runGit, f.request), /origin/);
  assert.equal(f.commands.some(args => args.includes('credential')), false);
});

test('a credential for another account is rejected before push', async () => {
  const f = fixture({ account: 'Iris9600' });
  await assert.rejects(pushCommittedChanges(f.runGit, f.request), /not Solar/);
  assert.equal(f.commands.some(args => args.includes('push')), false);
});

test('unaccepted collaborator access stops the push', async () => {
  const f = fixture({ writeAccess: false });
  await assert.rejects(pushCommittedChanges(f.runGit, f.request), /write access/);
  assert.equal(f.commands.some(args => args.includes('push')), false);
});

test('remote rejection never triggers a force-push or merge', async () => {
  const f = fixture({ pushFails: true });
  await assert.rejects(pushCommittedChanges(f.runGit, f.request), /rejected/);
  assert.equal(f.commands.filter(args => args.includes('push')).length, 1);
  assert.equal(f.commands.some(args => args.includes('--force') || args.includes('merge')), false);
});
