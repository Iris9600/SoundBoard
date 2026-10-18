import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';

// Validate draft rules without creating a ruleset, publishing, or writing data.
const login = JSON.parse(execFileSync('cmd.exe', ['/d', '/s', '/c', 'firebase.cmd login:list --json'], {
  encoding: 'utf8', timeout: 15000, windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'],
}));
const token = login.result?.[0]?.tokens?.access_token;
if (!token) throw new Error('Firebase CLI login required.');
const content = readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8');
const checks = [
  ['ALLOW', 'get', 'devices/name_YWxpY2U'],
  ['ALLOW', 'get', 'devices/name_YWxpY2U/sounds/bell'],
  ['DENY', 'get', 'devices/cd5ed331684f45eb8ce58cdafcb01667'],
  ['DENY', 'delete', 'devices/name_YWxpY2U'],
  ['DENY', 'list', 'devices'],
  ['DENY', 'get', 'Sound/bell'],
];
const response = await fetch('https://firebaserules.googleapis.com/v1/projects/soundboard-95778:test', {
  method: 'POST',
  headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
  body: JSON.stringify({
    source: { files: [{ name: 'firestore.rules', content }] },
    testSuite: { testCases: checks.map(([expectation, method, path]) => ({
      expectation, request: { method, path: `/databases/(default)/documents/${path}` },
    })) },
  }),
  signal: AbortSignal.timeout(20000),
});
const result = await response.json();
if (!response.ok) throw new Error(`Rules check failed (${response.status}): ${result.error?.message ?? 'Unknown error'}`);
console.log(JSON.stringify(result));
if (result.issues?.some(issue => issue.severity === 'ERROR')) process.exitCode = 1;
if (result.testResults?.length !== checks.length || result.testResults.some(test => test.state !== 'SUCCESS')) process.exitCode = 1;
