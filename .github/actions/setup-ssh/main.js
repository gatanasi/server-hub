const fs = require('fs');
const os = require('os');
const path = require('path');

const sshDir = path.join(os.homedir(), '.ssh');
if (!fs.existsSync(sshDir)) {
  fs.mkdirSync(sshDir, { mode: 0o700, recursive: true });
}

const knownHosts = process.env['INPUT_SSH-KNOWN-HOSTS'];
if (knownHosts) {
  fs.appendFileSync(path.join(sshDir, 'known_hosts'), knownHosts + '\n', { mode: 0o644 });
}

const privateKey = process.env['INPUT_SSH-PRIVATE-KEY'];
if (privateKey) {
  fs.writeFileSync(path.join(sshDir, 'deploy_key'), privateKey + '\n', { mode: 0o600 });
}
