const fs = require('fs');
const os = require('os');
const path = require('path');
const {
  KNOWN_HOSTS_BLOCK_END,
  KNOWN_HOSTS_BLOCK_START,
  removeManagedKnownHostsBlock,
} = require('./known-hosts-utils');

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
  const normalizedInputName = inputName.toUpperCase();
  const primaryEnvName = `INPUT_${normalizedInputName.replace(/-/g, '_')}`;
  const hyphenatedEnvName = `INPUT_${normalizedInputName}`;

  if (typeof process.env[primaryEnvName] === 'string') {
    return process.env[primaryEnvName];
  }

  if (typeof process.env[hyphenatedEnvName] === 'string') {
    return process.env[hyphenatedEnvName];
  }

  return undefined;
}

function saveActionState(name, value) {
  const stateFilePath = process.env.GITHUB_STATE;
  if (typeof stateFilePath !== 'string' || stateFilePath.length === 0) {
    return;
  }

  fs.appendFileSync(stateFilePath, `${name}=${value}\n`);
}

const sshDir = path.join(os.homedir(), '.ssh');
if (!fs.existsSync(sshDir)) {
  fs.mkdirSync(sshDir, { recursive: true });
}
fs.chmodSync(sshDir, SSH_DIR_MODE);

const knownHostsPath = path.join(sshDir, 'known_hosts');
const knownHostsExistedBefore = fs.existsSync(knownHostsPath);
saveActionState('KNOWN_HOSTS_EXISTED_BEFORE', knownHostsExistedBefore ? '1' : '0');

const normalizedKnownHosts = getRequiredNormalizedInput(
  'ssh-known-hosts',
  getActionInput('ssh-known-hosts')
);

let existingContent = '';
if (knownHostsExistedBefore) {
  existingContent = fs.readFileSync(knownHostsPath, 'utf8');
  existingContent = removeManagedKnownHostsBlock(existingContent);
}

const existingWithTrailingNewline =
  existingContent && !existingContent.endsWith('\n') ? `${existingContent}\n` : existingContent;
const managedBlock =
  `${KNOWN_HOSTS_BLOCK_START}\n` +
  `${normalizedKnownHosts}\n` +
  `${KNOWN_HOSTS_BLOCK_END}\n`;

fs.writeFileSync(knownHostsPath, `${existingWithTrailingNewline}${managedBlock}`, {
  mode: KNOWN_HOSTS_MODE,
});
fs.chmodSync(knownHostsPath, KNOWN_HOSTS_MODE);

const keyPath = path.join(sshDir, 'deploy_key');
const normalizedPrivateKey = getRequiredNormalizedInput(
  'ssh-private-key',
  getActionInput('ssh-private-key')
);

fs.writeFileSync(keyPath, `${normalizedPrivateKey}\n`, { mode: PRIVATE_KEY_MODE });
fs.chmodSync(keyPath, PRIVATE_KEY_MODE);
