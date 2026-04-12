const fs = require('fs');
const os = require('os');
const path = require('path');

const SSH_DIR_MODE = 0o700;
const PRIVATE_KEY_MODE = 0o600;
const KNOWN_HOSTS_MODE = 0o644;
const KNOWN_HOSTS_BLOCK_START = '# BEGIN managed by setup-ssh action';
const KNOWN_HOSTS_BLOCK_END = '# END managed by setup-ssh action';

function normalizeMultilineInput(value) {
  return value
    .split(/\r?\n/)
    .map((line) => line.trimEnd())
    .join('\n')
    .trim();
}

function removeManagedKnownHostsBlock(content) {
  const escapedStart = KNOWN_HOSTS_BLOCK_START.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const escapedEnd = KNOWN_HOSTS_BLOCK_END.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const blockRegex = new RegExp(`${escapedStart}\\n[\\s\\S]*?\\n${escapedEnd}\\n?`, 'g');
  return content.replace(blockRegex, '');
}

const sshDir = path.join(os.homedir(), '.ssh');
if (!fs.existsSync(sshDir)) {
  fs.mkdirSync(sshDir, { recursive: true });
}
fs.chmodSync(sshDir, SSH_DIR_MODE);

const knownHosts = process.env.INPUT_SSH_KNOWN_HOSTS;
if (knownHosts) {
  const knownHostsPath = path.join(sshDir, 'known_hosts');
  const normalizedKnownHosts = normalizeMultilineInput(knownHosts);

  if (normalizedKnownHosts) {
    let existingContent = '';
    if (fs.existsSync(knownHostsPath)) {
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
  }
}

const privateKey = process.env.INPUT_SSH_PRIVATE_KEY;
if (privateKey) {
  const keyPath = path.join(sshDir, 'deploy_key');
  const normalizedPrivateKey = normalizeMultilineInput(privateKey);

  if (normalizedPrivateKey) {
    fs.writeFileSync(keyPath, `${normalizedPrivateKey}\n`, { mode: PRIVATE_KEY_MODE });
    fs.chmodSync(keyPath, PRIVATE_KEY_MODE);
  }
}
