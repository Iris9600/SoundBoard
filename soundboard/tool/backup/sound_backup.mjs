import fs from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { DatabaseSync } from 'node:sqlite';
import { fileURLToPath } from 'node:url';
import { firebaseAccessToken, collectSnapshot } from './firestore_snapshot.mjs';

const KIND = 'soundboard-firestore-backup-v1';
const ROOT_MARKER = '.soundboard-backup-root.json';
const PENDING = /^\.pending-f([1-9]\d*)$/;
const COMPLETE = /^f([1-9]\d*)$/;
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
const readJson = file => JSON.parse(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, ''));

export function stableJson(value) {
  if (Array.isArray(value)) return `[${value.map(stableJson).join(',')}]`;
  if (value !== null && typeof value === 'object') {
    return `{${Object.keys(value).sort().map(key => `${JSON.stringify(key)}:${stableJson(value[key])}`).join(',')}}`;
  }
  return JSON.stringify(value);
}

export function snapshotFingerprint(snapshot) {
  return hash(stableJson({
    projectId: snapshot.projectId, databaseId: snapshot.databaseId,
    documents: [...snapshot.documents].sort((a, b) => a.name.localeCompare(b.name)),
  }));
}

export function deviceFolder(name, id) {
  if (!/^[a-f0-9]{32}$/.test(id)) throw new Error('Invalid installation ID in Firestore path.');
  const label = String(name || 'Unnamed-device')
    .replace(/[<>:"/\\|?*\x00-\x1f]/g, '_').replace(/[. ]+$/g, '').slice(0, 60);
  return `${label || 'Unnamed-device'}--${id}`;
}

function checkedChild(root, relative) {
  const resolvedRoot = fs.realpathSync(root);
  const candidate = path.resolve(resolvedRoot, relative);
  const relationship = path.relative(resolvedRoot, candidate);
  if (!relationship || relationship.startsWith('..') || path.isAbsolute(relationship)) {
    throw new Error('Backup path escapes its configured root.');
  }
  let cursor = resolvedRoot;
  for (const segment of relationship.split(path.sep)) {
    cursor = path.join(cursor, segment);
    if (fs.existsSync(cursor) && fs.lstatSync(cursor).isSymbolicLink()) {
      throw new Error('Refusing a symbolic link or junction inside a backup.');
    }
  }
  return candidate;
}

function writeJson(file, value) {
  fs.writeFileSync(file, JSON.stringify(value, null, 2) + '\n', { flag: 'wx' });
}

export function initialiseRoot(root, projectId) {
  fs.mkdirSync(root, { recursive: true });
  const marker = checkedChild(root, ROOT_MARKER);
  if (!fs.existsSync(marker)) {
    if (fs.readdirSync(root).length) throw new Error('Sound folder already contains files but is not a managed backup root.');
    writeJson(marker, { kind: KIND, projectId });
  }
  const saved = readJson(marker);
  if (saved.kind !== KIND || saved.projectId !== projectId) throw new Error('Backup root belongs to another project.');
}

function sqliteExport(file, documents, snapshot, deviceId) {
  const database = new DatabaseSync(file);
  try {
    database.exec(`
      PRAGMA journal_mode = DELETE;
      PRAGMA synchronous = FULL;
      CREATE TABLE metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL);
      CREATE TABLE documents (path TEXT PRIMARY KEY, firestore_json TEXT NOT NULL);
      CREATE TABLE sounds (id TEXT PRIMARY KEY, name TEXT, device_id TEXT, device_name TEXT,
                           audio_data TEXT, audio_bytes BLOB, created_at TEXT);
      BEGIN TRANSACTION;
    `);
    const meta = database.prepare('INSERT INTO metadata VALUES (?, ?)');
    for (const [key, value] of Object.entries({ projectId: snapshot.projectId, readTime: snapshot.readTime, deviceId: deviceId ?? '' })) {
      meta.run(key, value);
    }
    const insert = database.prepare('INSERT INTO documents VALUES (?, ?)');
    const sound = database.prepare('INSERT INTO sounds VALUES (?, ?, ?, ?, ?, ?, ?)');
    const prefix = `projects/${snapshot.projectId}/databases/(default)/documents/`;
    for (const document of documents) {
      const relative = document.name.slice(prefix.length);
      insert.run(relative, JSON.stringify(document));
      const segments = relative.split('/');
      if (segments.length === 4 && segments[0] === 'devices' && segments[2] === 'sounds') {
        const fields = document.fields ?? {};
        const audio = fields.url?.stringValue ?? '';
        // Preserve URLs in audio_data. Only embedded Base64 is stored as bytes.
        const embedded = /^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/.test(audio) && audio.length > 0;
        sound.run(segments[3], fields.name?.stringValue ?? null,
          fields.deviceId?.stringValue ?? deviceId, fields.deviceName?.stringValue ?? null,
          audio, embedded ? Buffer.from(audio, 'base64') : null, fields.createdAt?.timestampValue ?? null);
      }
    }
    database.exec('COMMIT');
    if (database.prepare('PRAGMA integrity_check').get().integrity_check !== 'ok') throw new Error('SQLite integrity verification failed.');
    if (database.prepare('SELECT count(*) AS total FROM documents').get().total !== documents.length) throw new Error('SQLite document count mismatch.');
    const recovered = database.prepare('SELECT firestore_json FROM documents ORDER BY path').all()
      .map(row => JSON.parse(row.firestore_json)).sort((a, b) => a.name.localeCompare(b.name));
    if (stableJson(recovered) !== stableJson([...documents].sort((a, b) => a.name.localeCompare(b.name)))) {
      throw new Error('SQLite data read-back mismatch.');
    }
  } finally {
    database.close(); // Closed standalone database only; no live WAL is synced.
  }
}

export function stageSnapshot(root, snapshot, date = new Date()) {
  const fingerprint = snapshotFingerprint(snapshot);
  const completed = listBackups(root, snapshot.projectId);
  const latest = completed.sort((a, b) => b.sequence - a.sequence)[0];
  if (latest?.manifest.fingerprint === fingerprint) return { status: 'unchanged', sequence: latest.sequence };
  const existing = fs.readdirSync(root);
  if (existing.some(name => PENDING.test(name))) return { status: 'pending', reason: 'An earlier backup is awaiting OneDrive upload.' };
  const sequence = existing.reduce((max, name) => {
    const match = COMPLETE.exec(name) || PENDING.exec(name);
    return match ? Math.max(max, Number(match[1])) : max;
  }, 0) + 1;
  if (!Number.isSafeInteger(sequence)) throw new Error('Backup sequence is out of range.');
  const folder = checkedChild(root, `.pending-f${sequence}`);
  fs.mkdirSync(folder);
  const files = [];
  function record(relative) {
    const file = checkedChild(folder, relative);
    const content = fs.readFileSync(file);
    files.push({ path: relative, bytes: content.length, sha256: hash(content) });
  }
  const prefix = `projects/${snapshot.projectId}/databases/(default)/documents/`;
  const devices = new Map();
  const unassigned = [];
  let urlReferences = 0;
  for (const document of snapshot.documents) {
    if (!document.name.startsWith(prefix)) throw new Error('Snapshot includes another Firebase project.');
    const segments = document.name.slice(prefix.length).split('/');
    if (segments[0] === 'devices' && segments.length >= 2 && /^[a-f0-9]{32}$/.test(segments[1])) {
      const id = segments[1];
      if (!devices.has(id)) devices.set(id, { id, name: null, documents: [] });
      const device = devices.get(id);
      device.documents.push(document);
      if (segments.length === 2) device.name = document.fields?.deviceName?.stringValue;
      if (!device.name) device.name = document.fields?.deviceName?.stringValue ?? null;
    } else unassigned.push(document);
    if (/^https?:\/\//i.test(document.fields?.url?.stringValue ?? '')) urlReferences++;
  }
  writeJson(checkedChild(folder, 'firestore.json'), snapshot);
  record('firestore.json');
  const deviceList = [];
  for (const device of devices.values()) {
    const relative = deviceFolder(device.name, device.id);
    fs.mkdirSync(checkedChild(folder, relative));
    sqliteExport(checkedChild(folder, `${relative}/sounds.sqlite`), device.documents, snapshot, device.id);
    record(`${relative}/sounds.sqlite`);
    deviceList.push({ deviceId: device.id, deviceName: device.name, folder: relative, documentCount: device.documents.length });
  }
  if (unassigned.length) {
    sqliteExport(checkedChild(folder, 'unassigned.sqlite'), unassigned, snapshot, null);
    record('unassigned.sqlite');
  }
  const manifest = {
    kind: KIND, projectId: snapshot.projectId, sequence, ready: true,
    createdAt: date.toISOString(), timeZone: 'Asia/Kuala_Lumpur', readTime: snapshot.readTime,
    fingerprint, documentCount: snapshot.documents.length, devices: deviceList,
    urlReferences, files,
  };
  writeJson(checkedChild(folder, 'manifest.json'), manifest);
  verifyBackup(folder, snapshot.projectId);
  return { status: 'staged', sequence, folder, documentCount: snapshot.documents.length, urlReferences };
}

export function verifyBackup(folder, projectId) {
  const manifest = readJson(checkedChild(folder, 'manifest.json'));
  if (manifest.kind !== KIND || manifest.projectId !== projectId || manifest.ready !== true) throw new Error('Unrecognised or incomplete backup.');
  for (const file of manifest.files) {
    const bytes = fs.readFileSync(checkedChild(folder, file.path));
    if (bytes.length !== file.bytes || hash(bytes) !== file.sha256) throw new Error('Backup checksum mismatch.');
  }
  const snapshot = readJson(checkedChild(folder, 'firestore.json'));
  if (snapshot.documents.length !== manifest.documentCount || snapshotFingerprint(snapshot) !== manifest.fingerprint) {
    throw new Error('Backup snapshot verification failed.');
  }
  return manifest;
}

function listBackups(root, projectId) {
  return fs.readdirSync(root).filter(name => COMPLETE.test(name)).map(name => {
    const folder = checkedChild(root, name);
    const manifest = verifyBackup(folder, projectId);
    const sequence = Number(COMPLETE.exec(name)[1]);
    if (manifest.sequence !== sequence) throw new Error('Backup sequence does not match folder name.');
    return { folder, sequence, manifest };
  });
}

function rejectLinks(folder) {
  for (const entry of fs.readdirSync(folder, { withFileTypes: true })) {
    if (entry.isSymbolicLink()) throw new Error('Refusing to delete a backup containing a symbolic link or junction.');
    if (entry.isDirectory()) rejectLinks(checkedChild(folder, entry.name));
  }
}

export function maintainBackups(root, projectId, isCloudSynced) {
  initialiseRoot(root, projectId);
  const published = [];
  for (const name of fs.readdirSync(root).filter(name => PENDING.test(name))) {
    const pending = checkedChild(root, name);
    const manifest = verifyBackup(pending, projectId);
    const sequence = Number(PENDING.exec(name)[1]);
    if (manifest.sequence !== sequence) throw new Error('Pending sequence does not match folder.');
    if (!isCloudSynced(pending)) continue;
    const destination = checkedChild(root, `f${sequence}`);
    if (fs.existsSync(destination)) throw new Error('Completed backup destination already exists.');
    fs.renameSync(pending, destination);
    published.push(`f${sequence}`);
  }
  const complete = listBackups(root, projectId).sort((a, b) => a.sequence - b.sequence);
  const removed = [];
  // Only known, verified backup folders are eligible. Validate all targets first.
  const targets = complete.slice(0, Math.max(0, complete.length - 3));
  const newest = complete.at(-1);
  if (targets.length && !published.includes(`f${newest.sequence}`) && !isCloudSynced(newest.folder)) {
    return { published, removed, pending: true };
  }
  for (const backup of targets) rejectLinks(backup.folder);
  for (const backup of targets) {
    const safeTarget = checkedChild(root, path.basename(backup.folder));
    fs.rmSync(safeTarget, { recursive: true });
    removed.push(path.basename(safeTarget));
  }
  return { published, removed, pending: fs.readdirSync(root).some(name => PENDING.test(name)) };
}

function cloudSyncChecker(folder) {
  const script = path.join(path.dirname(fileURLToPath(import.meta.url)), 'check_onedrive_sync.ps1');
  const powershell = path.join(process.env.SystemRoot || 'C:\\Windows', 'System32/WindowsPowerShell/v1.0/powershell.exe');
  const output = execFileSync(powershell, ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', script, '-Folder', folder], {
    encoding: 'utf8', timeout: 60_000, windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'],
  });
  return JSON.parse(output.trim()).synced === true;
}

export async function run(config, maintenanceOnly = false) {
  if (!config.oneDriveRoot || !fs.existsSync(config.oneDriveRoot)) throw new Error('Configured OneDrive sync folder does not exist.');
  const root = path.join(fs.realpathSync(config.oneDriveRoot), 'Sound');
  initialiseRoot(root, config.projectId);
  // OS file lock lives in the workspace so OneDrive never synchronizes it.
  fs.mkdirSync(config.stateDirectory, { recursive: true });
  const lock = path.join(config.stateDirectory, 'backup.lock');
  let lockFd;
  try { lockFd = fs.openSync(lock, 'wx'); }
  catch (error) { if (error.code === 'EEXIST') throw new Error('Another backup is running, or a stale backup.lock needs inspection.'); throw error; }
  try {
    fs.writeFileSync(lockFd, `${process.pid}\n`);
    const maintenance = maintainBackups(root, config.projectId, cloudSyncChecker);
    if (maintenanceOnly) return { ...maintenance, root };
    if (maintenance.pending) return { status: 'pending', root, reason: 'Previous snapshot is waiting for OneDrive sync; existing backups retained.' };
    const token = firebaseAccessToken(config.firebaseCliPath, config.projectId);
    const snapshot = await collectSnapshot(config.projectId, token);
    const backup = stageSnapshot(root, snapshot);
    const after = maintainBackups(root, config.projectId, cloudSyncChecker);
    return { ...backup, ...after, root };
  } finally {
    fs.closeSync(lockFd);
    fs.unlinkSync(lock);
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  let config;
  try {
    const configIndex = process.argv.indexOf('--config');
    if (configIndex < 0 || !process.argv[configIndex + 1]) throw new Error('Provide --config <configuration.json>.');
    config = readJson(process.argv[configIndex + 1]);
    const result = await run(config, process.argv.includes('--maintenance'));
    console.log(JSON.stringify(result, null, 2));
    fs.appendFileSync(path.join(config.stateDirectory, 'backup.log'), `${new Date().toISOString()} ${JSON.stringify(result)}\n`);
  } catch (error) {
    // Do not include native CLI stderr or response bodies: these may contain tokens.
    const message = error.message || 'Backup failed.';
    console.error(message);
    if (config?.stateDirectory && fs.existsSync(config.stateDirectory)) {
      fs.appendFileSync(path.join(config.stateDirectory, 'backup.log'), `${new Date().toISOString()} ERROR ${message}\n`);
    }
    process.exitCode = 1;
  }
}
