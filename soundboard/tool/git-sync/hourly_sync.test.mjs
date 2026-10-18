import test from 'node:test';
import assert from 'node:assert/strict';
import { eligible, sync } from './hourly_sync.mjs';

function fixture(options = {}) {
  const commands = [], requests = [];
  let pending = options.pending ?? false;
  const runGit = args => {
    commands.push(args);
    if (args[0] === 'branch') return options.branch ?? 'D-Time';
    if (args[0] === 'remote') return 'https://github.com/Iris9600/SoundBoard.git';
    if (args[0] === 'diff') return args.includes('--cached') ? (options.staged ?? (options.clean ? '' : 'soundboard/lib/app.dart\0')) : (options.clean ? '' : 'soundboard/lib/app.dart\0');
    if (args[0] === 'ls-files') return '';
    if (args[0] === 'rev-list') return options.ahead ? '1' : '0';
    if (args.includes('credential')) return 'password=test\n';
    if (args[0] === 'rev-parse') return args.includes('--git-path') ? '.git-sync/nonexistent-test-marker' : 'a'.repeat(40);
    if (args.includes('ls-remote')) return options.remoteEqual ? 'a'.repeat(40) + '\trefs/heads/D-Time' : '';
    if (args.includes('commit') || args.includes('add') || args.includes('push')) return '';
    throw new Error('Unexpected command: ' + args.join(' '));
  };
  const request = async (uri, init) => {
    requests.push({ uri, method: init.method ?? 'GET' });
    let value;
    if (uri.endsWith('/user')) value = { login: options.wrongAccount ? 'other' : 'Solar-owo', id: 338115045 };
    else if (uri.includes('/compare/')) value = { ahead_by: 1 };
    else if (uri.includes('pulls?')) value = options.existingPR ? [{ html_url: 'existing' }] : [];
    else if (uri.endsWith('/pulls')) {
      if (options.prFails) throw new Error('network unavailable');
      value = { html_url: 'created' };
    } else value = { permissions: { push: true } };
    return { ok: true, json: async () => value };
  };
  const state = { pending: () => pending, save: () => { pending = true; }, clear: () => { pending = false; } };
  return { commands, requests, run: () => sync(runGit, request, state), pending: () => pending };
}

test('source qualifies; private files and unrelated checkouts do not', () => {
  for (const file of ['soundboard/lib/app.dart', 'soundboard/pubspec.lock', 'AGENTS.md']) assert.ok(eligible(file));
  for (const file of ['Developing-skill/code.js', '.git-sync/state.json', 'soundboard/.env.production', 'soundboard/credentials.json', 'soundboard/data.db', 'soundboard/backups/data.json', 'soundboard/tool/backup/config.local.json', 'soundboard/android/key.properties']) assert.equal(eligible(file), false, file);
});
test('unchanged run does not authenticate or write', async () => {
  const f = fixture({ clean: true });
  assert.equal((await f.run()).status, 'unchanged');
  assert.equal(f.requests.length, 0);
  assert.equal(f.commands.some(a => a.includes('commit') || a.includes('push')), false);
});
test('changes commit as Solar, push D-Time and open a PR', async () => {
  const f = fixture();
  assert.equal((await f.run()).pullRequest, 'created');
  assert.ok(f.commands.find(a => a.includes('commit')).includes('user.name=Solar'));
  assert.equal(f.commands.find(a => a.includes('push')).at(-1), 'refs/heads/D-Time:refs/heads/D-Time');
  assert.equal(f.commands.some(a => a.includes('merge') || a.includes('--force')), false);
  assert.equal(f.pending(), false);
});
test('existing PR is reused', async () => {
  const f = fixture({ existingPR: true });
  assert.equal((await f.run()).pullRequest, 'existing');
  assert.equal(f.requests.some(r => r.method === 'POST'), false);
});
test('PR failure leaves pending state and clean retries recover', async () => {
  const f = fixture({ prFails: true });
  await assert.rejects(f.run(), /network/);
  assert.equal(f.pending(), true);
  const retry = fixture({ clean: true, pending: true, remoteEqual: true });
  assert.equal((await retry.run()).pullRequest, 'created');
  assert.equal(retry.commands.some(a => a.includes('commit') || a.includes('push')), false);
});
test('wrong branch, staged secrets and wrong account stop before commit', async () => {
  for (const options of [{ branch: 'main' }, { staged: 'soundboard/credentials.json\0' }, { wrongAccount: true }]) {
    const f = fixture(options);
    await assert.rejects(f.run());
    assert.equal(f.commands.some(a => a.includes('commit') || a.includes('push')), false);
  }
});
