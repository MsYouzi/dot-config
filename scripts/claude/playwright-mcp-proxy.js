#!/usr/bin/env node
'use strict';

const { spawn, spawnSync } = require('node:child_process');
const { renameSync, unlinkSync, writeFileSync } = require('node:fs');
const readline = require('node:readline');

const root = process.env.CLAUDE_CLEANUP_ROOT || '';
const token = process.env.CLAUDE_CLEANUP_TOKEN || '';
const helper = process.env.CLAUDE_CLEANUP_HELPER || `${process.env.HOME}/.claude/session-cleanup.sh`;
const version = process.env.PLAYWRIGHT_MCP_VERSION || '0.0.79';
const privateRoot = process.env.PLAYWRIGHT_MCP_PRIVATE_ROOT === '1';
const playwrightTmp = `${root}/playwright-tmp`;
const playwrightOutput = `${root}/playwright-output`;
const closeMarker = `${root}/.playwright-close-active`;

if (!root || !token) {
  console.error('playwright-mcp-proxy: missing cleanup ownership environment');
  process.exit(1);
}

const child = spawn(
  'npx',
  [
    '--yes',
    `@playwright/mcp@${version}`,
    '--browser',
    'chromium',
    '--isolated',
    '--output-dir',
    playwrightOutput,
  ],
  {
    env: {
      ...process.env,
      TMPDIR: `${playwrightTmp}/`,
      TMP: `${playwrightTmp}/`,
      TEMP: `${playwrightTmp}/`,
      PWTEST_SOCKETS_DIR: `${playwrightTmp}/s`,
    },
    stdio: ['pipe', 'pipe', 'inherit'],
  },
);

let browserActive = false;
let browserGeneration = 0;
let cleanedAtExit = false;
let closeSucceeded = false;
let outputClosed = false;
let terminatingSignal = null;
let helperQueue = Promise.resolve();
const pendingClose = new Map();
const heldCloseResponses = [];

function idKey(id) {
  return JSON.stringify(id);
}

function runHelperAsync(command, label) {
  const run = () => new Promise((resolve) => {
    const cleanup = spawn(helper, [command, root, token], {
      stdio: ['ignore', 'ignore', 'inherit'],
    });
    let settled = false;
    const finish = () => {
      if (settled) return;
      settled = true;
      resolve();
    };
    cleanup.on('error', (error) => {
      console.error(`playwright-mcp-proxy: ${label} failed: ${error.message}`);
      finish();
    });
    cleanup.on('close', (code, signal) => {
      if (code !== 0 && signal === null) {
        console.error(`playwright-mcp-proxy: ${label} exited with status ${code}`);
      }
      finish();
    });
  });
  helperQueue = helperQueue.then(run, run);
  return helperQueue;
}

function cleanupPlaywrightAsync() {
  void runHelperAsync('cleanup-playwright', 'cleanup');
}

function setCloseMarker(active) {
  try {
    if (active) {
      const temporary = `${closeMarker}.${process.pid}`;
      writeFileSync(temporary, `token=${token}\n`, { encoding: 'utf8', mode: 0o600 });
      renameSync(temporary, closeMarker);
    } else {
      try {
        unlinkSync(closeMarker);
      } catch (error) {
        if (error.code !== 'ENOENT') throw error;
      }
    }
  } catch (error) {
    console.error(`playwright-mcp-proxy: close marker failed: ${error.message}`);
  }
}

function cleanupAtExitSync() {
  if (cleanedAtExit) return;
  cleanedAtExit = true;
  setCloseMarker(false);
  const command = privateRoot ? 'cleanup-owned' : 'cleanup-playwright';
  const result = spawnSync(helper, [command, root, token], {
    stdio: ['ignore', 'ignore', 'inherit'],
  });
  if (result.error) {
    console.error(`playwright-mcp-proxy: exit cleanup failed: ${result.error.message}`);
  }
}

function syntheticCloseResponse(message) {
  return {
    jsonrpc: message.jsonrpc || '2.0',
    id: message.id,
    result: {
      content: [{ type: 'text', text: 'No open Playwright browser session.' }],
      isError: false,
    },
  };
}

function disconnectClientOutput(error) {
  if (outputClosed) return;
  outputClosed = true;
  if (error && error.code !== 'EPIPE' && error.code !== 'ERR_STREAM_DESTROYED') {
    console.error(`playwright-mcp-proxy: client stdout failed: ${error.message}`);
  }
  clientLines.close();
  if (!child.stdin.destroyed) child.stdin.end();
}

function writeClient(line) {
  if (outputClosed) return;
  try {
    process.stdout.write(line);
  } catch (error) {
    disconnectClientOutput(error);
  }
}

const clientLines = readline.createInterface({ input: process.stdin, crlfDelay: Infinity });
const serverLines = readline.createInterface({ input: child.stdout, crlfDelay: Infinity });

process.stdout.on('error', disconnectClientOutput);
child.stdin.on('error', (error) => {
  if (error.code === 'EPIPE' || error.code === 'ERR_STREAM_DESTROYED') return;
  console.error(`playwright-mcp-proxy: child stdin failed: ${error.message}`);
});

clientLines.on('line', (line) => {
  let message;
  try {
    message = JSON.parse(line);
  } catch {
    child.stdin.write(`${line}\n`);
    return;
  }

  if (message.method === 'tools/call' && message.params && typeof message.params.name === 'string') {
    const toolName = message.params.name;
    if (toolName === 'browser_close' && Object.prototype.hasOwnProperty.call(message, 'id')) {
      if (!browserActive) {
        cleanupPlaywrightAsync();
        writeClient(`${JSON.stringify(syntheticCloseResponse(message))}\n`);
        return;
      }
      pendingClose.set(idKey(message.id), browserGeneration);
      if (pendingClose.size === 1) setCloseMarker(true);
    } else if (toolName !== 'browser_close' && toolName.startsWith('browser_')) {
      browserGeneration += 1;
      browserActive = true;
    }
  }

  child.stdin.write(`${line}\n`);
});

clientLines.on('close', () => {
  if (!child.stdin.destroyed) child.stdin.end();
});

serverLines.on('line', (line) => {
  let message;
  try {
    message = JSON.parse(line);
  } catch {
    writeClient(`${line}\n`);
    return;
  }

  if (Object.prototype.hasOwnProperty.call(message, 'id') &&
      (Object.prototype.hasOwnProperty.call(message, 'result') ||
       Object.prototype.hasOwnProperty.call(message, 'error'))) {
    const key = idKey(message.id);
    if (pendingClose.has(key)) {
      const closeGeneration = pendingClose.get(key);
      pendingClose.delete(key);
      heldCloseResponses.push(line);
      if (message.result && message.result.isError !== true && !message.error &&
          closeGeneration === browserGeneration) {
        browserActive = false;
        closeSucceeded = true;
      }
      if (pendingClose.size === 0) {
        setCloseMarker(false);
        if (closeSucceeded && !browserActive) cleanupPlaywrightAsync();
        closeSucceeded = false;
        for (const response of heldCloseResponses.splice(0)) writeClient(`${response}\n`);
      }
      return;
    }
  }

  writeClient(`${line}\n`);
});

serverLines.on('close', () => {
  if (!outputClosed) process.stdout.end();
});

child.on('error', (error) => {
  console.error(`playwright-mcp-proxy: failed to start Playwright MCP: ${error.message}`);
});

child.on('close', (code, signal) => {
  clientLines.close();
  setCloseMarker(false);
  void helperQueue.finally(() => {
    cleanupAtExitSync();
    if (signal || terminatingSignal) {
      process.exitCode = 128 + (signal === 'SIGHUP' || terminatingSignal === 'SIGHUP' ? 1 :
        signal === 'SIGINT' || terminatingSignal === 'SIGINT' ? 2 : 15);
      return;
    }
    process.exitCode = code === null ? 1 : code;
  });
});

for (const signal of ['SIGHUP', 'SIGINT', 'SIGTERM']) {
  process.on(signal, () => {
    terminatingSignal = signal;
    if (child.exitCode === null && child.signalCode === null) child.kill(signal);
  });
}

process.on('exit', cleanupAtExitSync);
