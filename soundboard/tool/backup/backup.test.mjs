import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { DatabaseSync } from 'node:sqlite';
import { initialiseRoot, stageSnapshot, maintainBackups, snapshotFingerprint, deviceFolder, verifyBackup } from './sound_backup.mjs';
import { collectSnapshot } from './firestore_snapshot.mjs';

const projectId = 'soundboard-95778';
const deviceId = 'cd5ed331684f45eb8ce58cdafcb01667';
const prefix = `projects/${projectId}/databases/(default)/documents`;

function snapshot(version = 1) {
  return {
    projectId, databaseId: '(default)', readTime: `2026-10-05T10:00:0${version}.000000Z`,
    documents: [
      { name: `${prefix}/devices/${deviceId}`, updateTime: '2026-10-05T09:00:00Z',
        fields: { deviceId: { stringValue: deviceId }, deviceName: { stringValue: 'SHao' } } },
      { name: `${prefix}/devices/${deviceId}/sounds/sound-one`, updateTime: `2026-10-05T09:00:0${version}Z`,
        fields: { name: { stringValue: `Bell ${version}` }, deviceId: { stringValue: deviceId },
          deviceName: { stringValue: 'SHao' }, url: { stringValue: Buffer.from([1, 2, 3, 4]).toString('base64') },
          createdAt: { timestampValue: '2026-10-05T09:00:00Z' }, extra: { integerValue: '9007199254740993' } } },
    ],
  };
}

function fixture(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'soundboard-backup-test-'));
  const canonical = fs.realpathSync(root);
  t.after(() => {
    // Only delete this exact test-created directory, never a computed parent.
    assert.equal(fs.realpathSync(root), canonical);
    assert.ok(path.basename(root).startsWith('soundboard-backup-test-'));
    fs.rmSync(root, { recursive: true });
  });
  initialiseRoot(root, projectId);
  return root;
}

test('SQLite read-back preserves sound bytes and exact Firestore integer/timestamp types', t => {
  const root = fixture(t);
  const staged = stageSnapshot(root, snapshot());
  const sqlite = new DatabaseSync(path.join(staged.folder, `SHao--${deviceId}/sounds.sqlite`), { readOnly: true });
  try {
    const sound = sqlite.prepare('SELECT * FROM sounds').get();
    assert.equal(sound.name, 'Bell 1');
    assert.equal(sound.device_id, deviceId);
    assert.deepEqual(Buffer.from(sound.audio_bytes), Buffer.from([1, 2, 3, 4]));
    const document = JSON.parse(sqlite.prepare('SELECT firestore_json FROM documents WHERE path LIKE ?').get('%/sounds/%').firestore_json);
    assert.equal(document.fields.extra.integerValue, '9007199254740993');
    assert.equal(sqlite.prepare('PRAGMA integrity_check').get().integrity_check, 'ok');
  } finally { sqlite.close(); }
  assert.equal(verifyBackup(staged.folder, projectId).documentCount, 2);
});

test('fourth uploaded snapshot removes f1 and retains f2, f3, f4', t => {
  const root = fixture(t);
  for (let version = 1; version <= 4; version++) {
    assert.equal(stageSnapshot(root, snapshot(version)).sequence, version);
    const result = maintainBackups(root, projectId, () => true);
    assert.deepEqual(result.removed, version === 4 ? ['f1'] : []);
  }
  assert.deepEqual(fs.readdirSync(root).filter(name => /^f\d+$/.test(name)).sort(), ['f2', 'f3', 'f4']);
  assert.equal(stageSnapshot(root, snapshot(5)).sequence, 5);
});

test('failed or pending cloud upload never removes earlier backups', t => {
  const root = fixture(t);
  for (let version = 1; version <= 3; version++) {
    stageSnapshot(root, snapshot(version));
    maintainBackups(root, projectId, () => true);
  }
  stageSnapshot(root, snapshot(4));
  assert.equal(maintainBackups(root, projectId, () => false).pending, true);
  assert.ok(fs.existsSync(path.join(root, 'f1')));
  assert.ok(fs.existsSync(path.join(root, '.pending-f4')));
  assert.equal(stageSnapshot(root, snapshot(5)).status, 'pending');
  const result = maintainBackups(root, projectId, () => true);
  assert.deepEqual(result.removed, ['f1']);
});

test('unchanged snapshot does not consume a sequence number', t => {
  const root = fixture(t);
  stageSnapshot(root, snapshot());
  maintainBackups(root, projectId, () => true);
  const same = snapshot();
  same.readTime = '2026-10-06T10:00:00Z';
  same.documents.reverse();
  assert.equal(snapshotFingerprint(same), snapshotFingerprint(snapshot()));
  assert.equal(stageSnapshot(root, same).status, 'unchanged');
});

test('corrupted latest backup blocks rotation and retains oldest', t => {
  const root = fixture(t);
  for (let version = 1; version <= 3; version++) {
    stageSnapshot(root, snapshot(version));
    maintainBackups(root, projectId, () => true);
  }
  const staged = stageSnapshot(root, snapshot(4));
  fs.appendFileSync(path.join(staged.folder, 'firestore.json'), 'corrupted');
  assert.throws(() => maintainBackups(root, projectId, () => true), /checksum/);
  assert.ok(fs.existsSync(path.join(root, 'f1')));
});

test('unsafe device names cannot escape folders and same names remain separate', () => {
  assert.equal(deviceFolder('../SHao:/', deviceId).includes('/'), false);
  assert.notEqual(deviceFolder('SHao', deviceId), deviceFolder('SHao', '11111111111111111111111111111111'));
  assert.throws(() => deviceFolder('SHao', '../escape'), /Invalid/);
});

test('existing unmanaged root and other-project root are refused', t => {
  const root = fixture(t);
  assert.throws(() => initialiseRoot(root, 'another-project'), /another project/);
  const unmanaged = path.join(root, 'unmanaged');
  fs.mkdirSync(unmanaged);
  fs.writeFileSync(path.join(unmanaged, 'important.txt'), 'Keep me');
  assert.throws(() => initialiseRoot(unmanaged, projectId), /already contains/);
  assert.equal(fs.readFileSync(path.join(unmanaged, 'important.txt'), 'utf8'), 'Keep me');
});

test('documents outside device paths are also preserved', t => {
  const root = fixture(t);
  const data = snapshot();
  data.documents.push({ name: `${prefix}/settings/global`, updateTime: '2026-10-05T09:00:00Z', fields: { label: { stringValue: 'Settings' } } });
  const staged = stageSnapshot(root, data);
  const database = new DatabaseSync(path.join(staged.folder, 'unassigned.sqlite'), { readOnly: true });
  try { assert.equal(database.prepare('SELECT path FROM documents').get().path, 'settings/global'); }
  finally { database.close(); }
  assert.equal(verifyBackup(staged.folder, projectId).documentCount, 3);
});

test('snapshot traversal paginates and discovers sounds beneath missing parents at one read time', async () => {
  const readTime = '2026-10-05T10:00:00.000000Z';
  const calls = [];
  async function request(uri, options) {
    const url = new URL(uri);
    const body = options.body ? JSON.parse(options.body) : null;
    calls.push({ url, body });
    let result;
    if (url.pathname.endsWith(':runQuery')) result = [{ readTime }];
    else if (url.pathname === `/v1/${prefix}:listCollectionIds`) {
      result = body.pageToken ? { collectionIds: [] } : { collectionIds: ['devices'], nextPageToken: 'collections-page-2' };
    } else if (url.pathname === `/v1/${prefix}/devices`) {
      result = { documents: [{ name: `${prefix}/devices/${deviceId}` }] }; // Parent is missing.
    } else if (url.pathname === `/v1/${prefix}/devices/${deviceId}:listCollectionIds`) {
      result = { collectionIds: ['sounds'] };
    } else if (url.pathname === `/v1/${prefix}/devices/${deviceId}/sounds`) {
      result = url.searchParams.has('pageToken') ? { documents: [] } : { documents: [snapshot().documents[1]], nextPageToken: 'sounds-page-2' };
    } else result = { collectionIds: [] };
    return { ok: true, json: async () => result };
  }
  const data = await collectSnapshot(projectId, 'not-a-real-token', request);
  assert.equal(data.documents.length, 1);
  for (const call of calls.filter(call => !call.url.pathname.endsWith(':runQuery'))) {
    assert.equal(call.body?.readTime ?? call.url.searchParams.get('readTime'), readTime);
    if (!call.body) assert.equal(call.url.searchParams.get('showMissing'), 'true');
  }
  assert.ok(calls.some(call => call.body?.pageToken === 'collections-page-2'));
  assert.ok(calls.some(call => call.url.searchParams.get('pageToken') === 'sounds-page-2'));
});

test('Firestore access failure produces an error without leaking a token', async () => {
  await assert.rejects(collectSnapshot(projectId, 'SECRET-TOKEN', async () => ({ ok: false, status: 403 })), error => {
    assert.match(error.message, /403/);
    assert.equal(error.message.includes('SECRET-TOKEN'), false);
    return true;
  });
});
