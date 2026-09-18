#!/usr/bin/env node
'use strict';

const { spawn } = require('node:child_process');
const { chmodSync, mkdtempSync, mkdirSync, rmSync, writeFileSync } = require('node:fs');
const { tmpdir } = require('node:os');
const path = require('node:path');
const readline = require('node:readline');

const repoRoot = path.resolve(__dirname, '..');
const helper = path.join(repoRoot, 'scripts/claude/session-cleanup.sh');
const proxy = path.join(repoRoot, 'scripts/claude/playwright-mcp-proxy.js');
const state = mkdtempSync(path.join(tmpdir(), 'playwright-proxy-test-'));
const home = path.join(state, 'home');
const cleanupBase = path.join(state, 'cleanup');
const bin = path.join(state, 'bin');
mkdirSync(home, { recursive: true });
mkdirSync(bin);

function run(command, args, options = {}) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, options);
    let stdout = '';
    if (child.stdout) child.stdout.on('data', chunk => { stdout += chunk; });
    child.on('error', reject);
    child.on('close', code => code === 0 ? resolve(stdout) : reject(new Error(`${command} exited ${code}`)));
  });
}

async function main() {
  const allocation = await run(helper, ['allocate', 'playwright'], {
    env: { ...process.env, HOME: home, CLAUDE_CLEANUP_BASE: cleanupBase },
    stdio: ['ignore', 'pipe', 'inherit'],
  });
  const [root, token] = allocation.trim().split('\t');
  for (let i = 0; i < 100; i += 1) writeFileSync(path.join(root, 'playwright-output', `f${i}`), 'x');

  const fakeServer = path.join(state, 'fake-server.js');
  writeFileSync(fakeServer, `
'use strict';
const readline = require('node:readline');
const rl = readline.createInterface({ input: process.stdin, crlfDelay: Infinity });
function send(message) { process.stdout.write(JSON.stringify(message) + '\\n'); }
rl.on('line', line => {
  const message = JSON.parse(line);
  if (message.method === 'initialize') {
    send({jsonrpc:'2.0',id:message.id,result:{protocolVersion:'2025-03-26',capabilities:{},serverInfo:{name:'fake',version:'1'}}});
    return;
  }
  if (message.method !== 'tools/call') return;
  const result = {jsonrpc:'2.0',id:message.id,result:{content:[{type:'text',text:message.params.name}],isError:false}};
  if (message.params.name === 'browser_close') setTimeout(() => send(result), 250);
  else send(result);
});
`);
  const npx = path.join(bin, 'npx');
  writeFileSync(npx, `#!/usr/bin/env bash\nexec node "${fakeServer}"\n`, { mode: 0o755 });
  chmodSync(npx, 0o755);

  const child = spawn('node', [proxy], {
    env: {
      ...process.env,
      HOME: home,
      CLAUDE_CLEANUP_BASE: cleanupBase,
      CLAUDE_CLEANUP_ROOT: root,
      CLAUDE_CLEANUP_TOKEN: token,
      CLAUDE_CLEANUP_HELPER: helper,
      PATH: `${bin}:${process.env.PATH}`,
    },
    stdio: ['pipe', 'pipe', 'inherit'],
  });
  const exited = new Promise(resolve => child.once('close', resolve));
  const lines = readline.createInterface({ input: child.stdout, crlfDelay: Infinity });
  const responses = new Map();
  const messages = new Map();
  const start = performance.now();
  lines.on('line', line => {
    try {
      const message = JSON.parse(line);
      if (Object.prototype.hasOwnProperty.call(message, 'id') &&
          (Object.prototype.hasOwnProperty.call(message, 'result') ||
           Object.prototype.hasOwnProperty.call(message, 'error'))) {
        responses.set(message.id, performance.now() - start);
        messages.set(message.id, message);
      }
    } catch {}
  });
  const send = message => child.stdin.write(`${JSON.stringify(message)}\n`);
  const waitFor = (ids, timeout = 5000) => new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      clearInterval(poll);
      reject(new Error(`timeout waiting for ${ids.join(',')}`));
    }, timeout);
    const poll = setInterval(() => {
      if (ids.every(id => responses.has(id))) {
        clearTimeout(timer);
        clearInterval(poll);
        resolve();
      }
    }, 10);
  });

  try {
    send({ jsonrpc: '2.0', id: 1, method: 'initialize', params: {} });
    await waitFor([1]);
    send({ jsonrpc: '2.0', id: 2, method: 'tools/call', params: { name: 'browser_navigate', arguments: { url: 'x' } } });
    await waitFor([2]);
    send({ jsonrpc: '2.0', id: 3, method: 'tools/call', params: { name: 'browser_close', arguments: {} } });
    send({ jsonrpc: '2.0', id: 4, method: 'tools/call', params: { name: 'browser_snapshot', arguments: {} } });
    await waitFor([3, 4]);
    const closeMs = responses.get(3);
    const otherMs = responses.get(4);
    if (otherMs >= closeMs || closeMs - otherMs < 150) {
      throw new Error(`proxy blocked unrelated response: close=${closeMs} other=${otherMs}`);
    }

    // An older close must not hide browser activity that followed it.
    send({ jsonrpc: '2.0', id: 5, method: 'tools/call', params: { name: 'browser_navigate', arguments: { url: 'first' } } });
    await waitFor([5]);
    send({ jsonrpc: '2.0', id: 6, method: 'tools/call', params: { name: 'browser_close', arguments: {} } });
    send({ jsonrpc: '2.0', id: 7, method: 'tools/call', params: { name: 'browser_navigate', arguments: { url: 'reopened' } } });
    await waitFor([6, 7]);
    send({ jsonrpc: '2.0', id: 8, method: 'tools/call', params: { name: 'browser_close', arguments: {} } });
    await waitFor([8]);
    if (messages.get(8).result.content[0].text !== 'browser_close') {
      throw new Error('overlapping navigation was forgotten: final close never reached Playwright');
    }
    send({ jsonrpc: '2.0', id: 9, method: 'tools/call', params: { name: 'browser_close', arguments: {} } });
    await waitFor([9]);
    if (messages.get(9).result.content[0].text !== 'No open Playwright browser session.') {
      throw new Error('an idle close should remain synthetic');
    }
    console.log(`playwright proxy nonblocking cleanup and overlapping navigation ok: unrelated=${Math.round(otherMs)}ms close=${Math.round(closeMs)}ms`);
  } finally {
    child.stdin.end();
    const code = await exited;
    if (code !== 0) throw new Error(`proxy exited ${code}`);
  }
}

main()
  .finally(() => rmSync(state, { recursive: true, force: true }))
  .catch(error => {
    console.error(error.stack || error.message);
    process.exitCode = 1;
  });
