import { execFileSync } from 'node:child_process';

// CLI output stays in memory. In particular, login:list must never be logged.
export function firebaseAccessToken(firebaseCliPath, projectId) {
  function cli(args) {
    let output;
    try {
      output = execFileSync(process.execPath, [firebaseCliPath, ...args, '--json'], {
        encoding: 'utf8', timeout: 120_000, maxBuffer: 8 * 1024 * 1024,
        windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'],
      });
    } catch {
      throw new Error('Firebase login unavailable. Run firebase.cmd login --reauth as the scheduled-task user.');
    }
    const response = JSON.parse(output);
    if (response.status !== 'success') throw new Error('Firebase CLI operation failed.');
    return response.result;
  }
  // projects:list refreshes the saved account's access token when needed.
  const projects = cli(['projects:list']);
  if (!projects.some(project => project.projectId === projectId)) {
    throw new Error('Firebase account cannot access the configured project.');
  }
  const accounts = cli(['login:list']);
  if (accounts.length !== 1) {
    throw new Error('Backup requires exactly one Firebase CLI account to avoid using the wrong account.');
  }
  const token = accounts[0]?.tokens?.access_token;
  if (!token) throw new Error('Firebase access token unavailable.');
  return token;
}

export async function collectSnapshot(projectId, token, request = fetch) {
  if (!/^[a-z][a-z0-9-]+$/.test(projectId)) throw new Error('Invalid Firebase project ID.');
  const root = `projects/${projectId}/databases/(default)/documents`;
  async function api(relative, body) {
    const response = await request(`https://firestore.googleapis.com/v1/${relative}`, {
      method: body ? 'POST' : 'GET',
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      ...(body ? { body: JSON.stringify(body) } : {}),
      signal: AbortSignal.timeout(60_000),
    });
    if (!response.ok) throw new Error(`Firestore backup request failed (${response.status}). Previous backups are retained.`);
    return response.json();
  }

  const clock = await api(`${root}:runQuery`, {
    structuredQuery: {
      from: [{ collectionId: 'devices' }], limit: 1,
      select: { fields: [{ fieldPath: '__name__' }] },
    },
  });
  const readTime = clock.at(-1)?.readTime;
  if (!readTime) throw new Error('Firestore did not return a snapshot timestamp.');
  const documents = [];
  async function walk(parent) {
    let collectionToken;
    do {
      const result = await api(`${parent}:listCollectionIds`, {
        pageSize: 100, readTime, ...(collectionToken ? { pageToken: collectionToken } : {}),
      });
      for (const collectionId of result.collectionIds ?? []) {
        let documentToken;
        do {
          const query = new URLSearchParams({ pageSize: '100', showMissing: 'true', readTime });
          if (documentToken) query.set('pageToken', documentToken);
          const page = await api(`${parent}/${encodeURIComponent(collectionId)}?${query}`);
          for (const document of page.documents ?? []) {
            // Missing parent documents can still contain live subcollections.
            if (document.updateTime || document.createTime) documents.push(document);
            await walk(document.name);
          }
          documentToken = page.nextPageToken;
        } while (documentToken);
      }
      collectionToken = result.nextPageToken;
    } while (collectionToken);
  }
  await walk(root);
  documents.sort((a, b) => a.name.localeCompare(b.name));
  return { projectId, databaseId: '(default)', readTime, documents };
}
