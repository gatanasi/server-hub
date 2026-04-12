const fs = require('fs');
const os = require('os');
const path = require('path');

const sshDir = path.join(os.homedir(), '.ssh');

try {
  fs.unlinkSync(path.join(sshDir, 'deploy_key'));
  console.log('Successfully deleted ~/.ssh/deploy_key');
} catch (err) {
  if (err.code !== 'ENOENT') {
    console.error('Error deleting deploy_key:', err);
  }
}

try {
  fs.unlinkSync(path.join(sshDir, 'known_hosts'));
  console.log('Successfully deleted ~/.ssh/known_hosts');
} catch (err) {
  if (err.code !== 'ENOENT') {
    console.error('Error deleting known_hosts:', err);
  }
}
