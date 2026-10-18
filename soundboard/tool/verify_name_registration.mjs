import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { execFileSync } from 'node:child_process';

if (!process.argv.includes('--live')) throw new Error('Use --live to test a temporary profile in soundboard-95778.');
const login = JSON.parse(execFileSync('cmd.exe', ['/d', '/s', '/c', 'firebase.cmd login:list --json'], {
  encoding: 'utf8', timeout: 15000, windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'],
}));
const token = login.result?.[0]?.tokens?.access_token;
if (!token) throw new Error('Firebase CLI login required for test-profile cleanup.');
const root = 'projects/soundboard-95778/databases/(default)/documents';
const userName = `registration-check-${randomUUID()}`;
const libraryId = `name_${Buffer.from(userName).toString('base64url')}`;
const name = `${root}/devices/${libraryId}`;
async function request(path, method = 'GET', body, admin = false) {
  const response = await fetch(`https://firestore.googleapis.com/v1/${path}`, {
    method,
    headers: { 'Content-Type': 'application/json', ...(admin ? { Authorization: `Bearer ${token}` } : {}) },
    body: body ? JSON.stringify(body) : undefined,
    signal: AbortSignal.timeout(20000),
  });
  return { status: response.status, data: await response.json() };
}
let created = false;
try {
  const missing = await request(name);
  assert.equal(missing.status, 404, `Profile lookup blocked: ${JSON.stringify(missing.data)}`);
  const write = {
    update: { name, fields: { userName: { stringValue: userName }, libraryId: { stringValue: libraryId } } },
    updateTransforms: [{ fieldPath: 'createdAt', setToServerValue: 'REQUEST_TIME' }],
    currentDocument: { exists: false },
  };
  const registered = await request(`${root}:commit`, 'POST', { writes: [write] });
  assert.equal(registered.status, 200, `Registration blocked: ${JSON.stringify(registered.data)}`);
  created = true;
  const profile = await request(name);
  assert.equal(profile.status, 200);
  assert.equal(profile.data.fields.userName.stringValue, userName);
  assert.equal(profile.data.fields.libraryId.stringValue, libraryId);
  assert.ok(profile.data.fields.createdAt.timestampValue);
  const duplicate = await request(`${root}:commit`, 'POST', { writes: [write] });
  assert.notEqual(duplicate.status, 200, 'Duplicate registration unexpectedly succeeded.');
  const unchanged = await request(name);
  assert.deepEqual(unchanged.data.fields, profile.data.fields);
  console.log('Live profile creation, login lookup, saved attributes, and duplicate protection passed.');
} finally {
  if (created) {
    const deleted = await request(name, 'DELETE', undefined, true);
    assert.equal(deleted.status, 200, `Temporary profile cleanup failed: ${name}`);
    console.log('Temporary test profile removed.');
  }
}
