const fs = require('fs');
const os = require('os');
const path = require('path');
const { removeManagedKnownHostsBlock } = require('./known-hosts-utils');

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
    const knownHostsContent = fs.readFileSync(knownHostsPath, 'utf8');
    const updatedKnownHostsContent = removeManagedKnownHostsBlock(knownHostsContent);

    if (updatedKnownHostsContent === knownHostsContent) {
      console.log('No setup-ssh managed known_hosts block found; leaving file unchanged');
    } else if (updatedKnownHostsContent.length === 0) {
      if (knownHostsExistedBefore) {
        fs.writeFileSync(knownHostsPath, '');
        console.log('Removed setup-ssh managed entries and preserved pre-existing empty ~/.ssh/known_hosts');
      } else {
        fs.unlinkSync(knownHostsPath);
        console.log('Removed setup-ssh known_hosts entries and deleted action-created ~/.ssh/known_hosts');
      }
    } else {
      fs.writeFileSync(knownHostsPath, updatedKnownHostsContent);
      console.log('Removed setup-ssh managed entries from ~/.ssh/known_hosts while preserving remaining content');
    }
  }
} catch (err) {
  if (err.code !== 'ENOENT') {
    console.error('Error cleaning up known_hosts:', err);
    process.exitCode = 1;
  }
}
