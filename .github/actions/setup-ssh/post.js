const fs = require('fs');
const os = require('os');
const path = require('path');
const { removeManagedKnownHostsBlock } = require('./known-hosts-utils');

const sshDir = path.join(os.homedir(), '.ssh');
const keyPath = path.join(sshDir, 'deploy_key');
const knownHostsPath = path.join(sshDir, 'known_hosts');

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
    } else if (updatedKnownHostsContent.trim().length === 0) {
      fs.unlinkSync(knownHostsPath);
      console.log('Removed setup-ssh known_hosts entries and deleted empty ~/.ssh/known_hosts');
    } else {
      const normalizedContent = updatedKnownHostsContent.endsWith('\n')
        ? updatedKnownHostsContent
        : `${updatedKnownHostsContent}\n`;
      fs.writeFileSync(knownHostsPath, normalizedContent);
      console.log('Removed setup-ssh managed entries from ~/.ssh/known_hosts');
    }
  }
} catch (err) {
  if (err.code !== 'ENOENT') {
    console.error('Error deleting known_hosts:', err);
    process.exitCode = 1;
  }
}
