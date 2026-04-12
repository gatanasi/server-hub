const fs = require('fs');
const os = require('os');
const path = require('path');
const { removeManagedKnownHostsBlock } = require('./known-hosts-utils');

const KNOWN_HOSTS_DEFAULT_MODE = 0o644;
const READ_OPEN_FLAGS =
  fs.constants.O_RDONLY |
  (typeof fs.constants.O_NOFOLLOW === 'number' ? fs.constants.O_NOFOLLOW : 0);
const WRITE_OPEN_FLAGS =
  fs.constants.O_WRONLY |
  fs.constants.O_CREAT |
  fs.constants.O_TRUNC |
  (typeof fs.constants.O_NOFOLLOW === 'number' ? fs.constants.O_NOFOLLOW : 0);

function assertSafeRegularFile(filePath, label) {
  const stats = fs.lstatSync(filePath);

  if (stats.isSymbolicLink()) {
    throw new Error(`${label} at ${filePath} must not be a symlink`);
  }

  if (!stats.isFile()) {
    throw new Error(`${label} at ${filePath} must be a regular file`);
  }

  return stats;
}

function readSafeUtf8File(filePath, label) {
  let fileDescriptor;
  try {
    fileDescriptor = fs.openSync(filePath, READ_OPEN_FLAGS);
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

    return {
      content: fs.readFileSync(fileDescriptor, 'utf8'),
      mode: descriptorStats.mode & 0o777,
    };
  } finally {
    fs.closeSync(fileDescriptor);
  }
}

function writeSafeUtf8File(filePath, content, mode, label) {
  const targetMode = typeof mode === 'number' ? mode : KNOWN_HOSTS_DEFAULT_MODE;

  let fileDescriptor;
  try {
    fileDescriptor = fs.openSync(filePath, WRITE_OPEN_FLAGS, targetMode);
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

    fs.fchmodSync(fileDescriptor, targetMode);
    fs.writeFileSync(fileDescriptor, content, { encoding: 'utf8' });
  } finally {
    fs.closeSync(fileDescriptor);
  }
}

const sshDir = path.join(os.homedir(), '.ssh');
const keyPath = path.join(sshDir, 'deploy_key');
const knownHostsPath = path.join(sshDir, 'known_hosts');
const knownHostsExistedBefore = process.env.STATE_KNOWN_HOSTS_EXISTED_BEFORE === '1';

try {
  fs.unlinkSync(keyPath);
  console.log('Successfully deleted ~/.ssh/deploy_key');
} catch (err) {
  if (err.code !== 'ENOENT') {
    console.error('Error deleting deploy_key:', err);
    process.exitCode = 1;
  }
}

try {
  if (!fs.existsSync(knownHostsPath)) {
    console.log('Skipping known_hosts cleanup because ~/.ssh/known_hosts does not exist');
  } else {
    const { content: knownHostsContent, mode: knownHostsMode } = readSafeUtf8File(
      knownHostsPath,
      'known_hosts'
    );
    const updatedKnownHostsContent = removeManagedKnownHostsBlock(knownHostsContent);

    if (updatedKnownHostsContent === knownHostsContent) {
      console.log('No setup-ssh managed known_hosts block found; leaving file unchanged');
    } else if (updatedKnownHostsContent.length === 0) {
      if (knownHostsExistedBefore) {
        writeSafeUtf8File(knownHostsPath, '', knownHostsMode, 'known_hosts');
        console.log('Removed setup-ssh managed entries and preserved pre-existing empty ~/.ssh/known_hosts');
      } else {
        assertSafeRegularFile(knownHostsPath, 'known_hosts');
        fs.unlinkSync(knownHostsPath);
        console.log('Removed setup-ssh known_hosts entries and deleted action-created ~/.ssh/known_hosts');
      }
    } else {
      writeSafeUtf8File(knownHostsPath, updatedKnownHostsContent, knownHostsMode, 'known_hosts');
      console.log('Removed setup-ssh managed entries from ~/.ssh/known_hosts while preserving remaining content');
    }
  }
} catch (err) {
  if (err.code !== 'ENOENT') {
    console.error('Error cleaning up known_hosts:', err);
    process.exitCode = 1;
  }
}
