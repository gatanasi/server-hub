const fs = require('fs');
const os = require('os');
const path = require('path');
const { removeManagedKnownHostsBlock } = require('./known-hosts-utils');
const {
  assertSafeRegularFile,
  readSafeUtf8File,
  writeSafeUtf8File,
} = require('./secure-file-utils');

const sshDir = path.join(os.homedir(), '.ssh');
const knownHostsPath = path.join(sshDir, 'known_hosts');
const knownHostsExistedBefore = process.env.STATE_KNOWN_HOSTS_EXISTED_BEFORE === '1';
const deployKeyPath = process.env.STATE_DEPLOY_KEY_PATH;
const deployKeyTempDir = process.env.STATE_DEPLOY_KEY_TEMP_DIR;
const deployKeyCreated = process.env.STATE_DEPLOY_KEY_CREATED === '1';

if (!deployKeyCreated) {
  console.log('Skipping deploy_key cleanup because this run did not create a deploy key');
} else if (typeof deployKeyPath !== 'string' || deployKeyPath.length === 0) {
  console.log('Skipping deploy_key cleanup because no stateful deploy key path was recorded');
} else {
  try {
    assertSafeRegularFile(deployKeyPath, 'deploy_key');
    fs.unlinkSync(deployKeyPath);
    console.log(`Successfully deleted deploy key at ${deployKeyPath}`);
  } catch (err) {
    if (err.code === 'ENOENT') {
      console.log('Skipping deploy_key cleanup because recorded deploy key path no longer exists');
    } else {
      console.error('Error deleting deploy_key:', err);
      process.exitCode = 1;
    }
  }
}

if (deployKeyCreated && typeof deployKeyTempDir === 'string' && deployKeyTempDir.length > 0) {
  try {
    fs.rmSync(deployKeyTempDir, { recursive: false, force: false });
    console.log(`Removed setup-ssh temporary directory ${deployKeyTempDir}`);
  } catch (err) {
    if (err.code === 'ENOENT') {
      console.log('Skipping setup-ssh temporary directory cleanup because it does not exist');
    } else if (err.code === 'ENOTEMPTY') {
      console.log('Leaving setup-ssh temporary directory in place because it is not empty');
    } else {
      console.error('Error removing setup-ssh temporary directory:', err);
      process.exitCode = 1;
    }
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
        writeSafeUtf8File(knownHostsPath, '', knownHostsMode, 'known_hosts', knownHostsMode);
        console.log('Removed setup-ssh managed entries and preserved pre-existing empty ~/.ssh/known_hosts');
      } else {
        assertSafeRegularFile(knownHostsPath, 'known_hosts');
        fs.unlinkSync(knownHostsPath);
        console.log('Removed setup-ssh known_hosts entries and deleted action-created ~/.ssh/known_hosts');
      }
    } else {
      writeSafeUtf8File(
        knownHostsPath,
        updatedKnownHostsContent,
        knownHostsMode,
        'known_hosts',
        knownHostsMode
      );
      console.log('Removed setup-ssh managed entries from ~/.ssh/known_hosts while preserving remaining content');
    }
  }
} catch (err) {
  if (err.code !== 'ENOENT') {
    console.error('Error cleaning up known_hosts:', err);
    process.exitCode = 1;
  }
}
