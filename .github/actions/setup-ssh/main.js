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
const FILE_OPEN_FLAGS =
  fs.constants.O_WRONLY |
  fs.constants.O_CREAT |
  fs.constants.O_TRUNC |
  (typeof fs.constants.O_NOFOLLOW === 'number' ? fs.constants.O_NOFOLLOW : 0);

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

function assertSafeRegularFileOrAbsent(filePath, label) {
  if (!fs.existsSync(filePath)) {
    return false;
  }

  const stats = fs.lstatSync(filePath);
  if (stats.isSymbolicLink()) {
    throw new Error(`${label} at ${filePath} must not be a symlink`);
  }

  if (!stats.isFile()) {
    throw new Error(`${label} at ${filePath} must be a regular file`);
  }

  return true;
}

function writeSecureFile(filePath, content, mode, label) {
  assertSafeRegularFileOrAbsent(filePath, label);

  let fileDescriptor;
  try {
    fileDescriptor = fs.openSync(filePath, FILE_OPEN_FLAGS, mode);
  } catch (err) {
    if (err && err.code === 'ELOOP') {
      throw new Error(`${label} at ${filePath} must not be a symlink`);
    }

    throw err;
  }

  try {
    const descriptorStats = fs.fstatSync(fileDescriptor);
    if (!descriptorStats.isFile()) {
      throw new Error(`${label} at ${filePath} must be a regular file`);
    }

    fs.fchmodSync(fileDescriptor, mode);
    fs.writeFileSync(fileDescriptor, content, { encoding: 'utf8' });
  } finally {
    fs.closeSync(fileDescriptor);
  }
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

writeSecureFile(
  knownHostsPath,
  `${existingWithTrailingNewline}${managedBlock}`,
  KNOWN_HOSTS_MODE,
  'known_hosts'
);

const keyPath = path.join(sshDir, 'deploy_key');
const normalizedPrivateKey = getRequiredNormalizedInput(
  'ssh-private-key',
  getActionInput('ssh-private-key')
);

writeSecureFile(keyPath, `${normalizedPrivateKey}\n`, PRIVATE_KEY_MODE, 'deploy_key');
