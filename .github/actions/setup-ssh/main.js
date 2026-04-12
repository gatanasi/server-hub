const fs = require('fs');
const os = require('os');
const path = require('path');
const {
  KNOWN_HOSTS_BLOCK_END,
  KNOWN_HOSTS_BLOCK_START,
  removeManagedKnownHostsBlock,
} = require('./known-hosts-utils');
const {
  assertSafeRegularFileOrAbsent,
  readSafeUtf8File,
  writeSafeUtf8File,
} = require('./secure-file-utils');

const SSH_DIR_MODE = 0o700;
const PRIVATE_KEY_MODE = 0o600;
const KNOWN_HOSTS_MODE = 0o644;

function normalizeMultilineInput(value) {
  return value
    .split(/\r?\n/)
    .map((line) => line.trimEnd())
    .join('\n')
    .trim();
}

function getRequiredNormalizedInput(inputName, rawValue) {
  if (typeof rawValue !== 'string') {
    throw new Error(`Missing required input: ${inputName}`);
  }

  const normalizedValue = normalizeMultilineInput(rawValue);
  if (!normalizedValue) {
    throw new Error(`Input ${inputName} is required and cannot be empty`);
  }

  return normalizedValue;
}

function getActionInput(inputName) {
  const envName = `INPUT_${inputName.toUpperCase().replace(/ /g, '_')}`;
  const value = process.env[envName];
  return typeof value === 'string' ? value : undefined;
}

function saveActionState(name, value) {
  const stateFilePath = process.env.GITHUB_STATE;
  if (typeof stateFilePath !== 'string' || stateFilePath.length === 0) {
    return;
  }

  fs.appendFileSync(stateFilePath, `${name}=${value}\n`);
}

function saveActionOutput(name, value) {
  const outputFilePath = process.env.GITHUB_OUTPUT;
  if (typeof outputFilePath !== 'string' || outputFilePath.length === 0) {
    return;
  }

  fs.appendFileSync(outputFilePath, `${name}=${value}\n`);
}

function ensureSafeSshDirectory(sshDirectoryPath) {
  if (fs.existsSync(sshDirectoryPath)) {
    const stats = fs.lstatSync(sshDirectoryPath);
    if (stats.isSymbolicLink()) {
      throw new Error(`SSH directory at ${sshDirectoryPath} must not be a symlink`);
    }

    if (!stats.isDirectory()) {
      throw new Error(`SSH directory at ${sshDirectoryPath} must be a directory`);
    }
  } else {
    fs.mkdirSync(sshDirectoryPath, { recursive: true, mode: SSH_DIR_MODE });
  }

  fs.chmodSync(sshDirectoryPath, SSH_DIR_MODE);
}

const sshDir = path.join(os.homedir(), '.ssh');
ensureSafeSshDirectory(sshDir);

const knownHostsPath = path.join(sshDir, 'known_hosts');
const knownHostsExistedBefore = assertSafeRegularFileOrAbsent(knownHostsPath, 'known_hosts');
saveActionState('KNOWN_HOSTS_EXISTED_BEFORE', knownHostsExistedBefore ? '1' : '0');

const normalizedKnownHosts = getRequiredNormalizedInput(
  'ssh-known-hosts',
  getActionInput('ssh-known-hosts')
);

let existingContent = '';
let knownHostsMode = KNOWN_HOSTS_MODE;
if (knownHostsExistedBefore) {
  const existingKnownHosts = readSafeUtf8File(knownHostsPath, 'known_hosts');
  existingContent = existingKnownHosts.content;
  knownHostsMode = existingKnownHosts.mode;
  existingContent = removeManagedKnownHostsBlock(existingContent);
}

const existingWithTrailingNewline =
  existingContent && !existingContent.endsWith('\n') ? `${existingContent}\n` : existingContent;
const managedBlock =
  `${KNOWN_HOSTS_BLOCK_START}\n` +
  `${normalizedKnownHosts}\n` +
  `${KNOWN_HOSTS_BLOCK_END}\n`;

writeSafeUtf8File(
  knownHostsPath,
  `${existingWithTrailingNewline}${managedBlock}`,
  knownHostsMode,
  'known_hosts',
  KNOWN_HOSTS_MODE
);

const normalizedPrivateKey = getRequiredNormalizedInput(
  'ssh-private-key',
  getActionInput('ssh-private-key')
);

const runnerTempDir = process.env.RUNNER_TEMP || os.tmpdir();
const actionTempDir = fs.mkdtempSync(path.join(runnerTempDir, 'setup-ssh-'));
fs.chmodSync(actionTempDir, SSH_DIR_MODE);
const keyPath = path.join(actionTempDir, 'deploy_key');

// Persist cleanup state before writing so post.js can recover from mid-step failures.
saveActionState('DEPLOY_KEY_PATH', keyPath);
saveActionState('DEPLOY_KEY_TEMP_DIR', actionTempDir);
saveActionState('DEPLOY_KEY_CREATED', '1');

writeSafeUtf8File(keyPath, `${normalizedPrivateKey}\n`, PRIVATE_KEY_MODE, 'deploy_key', PRIVATE_KEY_MODE);

saveActionOutput('ssh-key-path', keyPath);
