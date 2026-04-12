const KNOWN_HOSTS_BLOCK_START = '# BEGIN managed by setup-ssh action';
const KNOWN_HOSTS_BLOCK_END = '# END managed by setup-ssh action';

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function removeManagedKnownHostsBlock(content) {
  const escapedStart = escapeRegExp(KNOWN_HOSTS_BLOCK_START);
  const escapedEnd = escapeRegExp(KNOWN_HOSTS_BLOCK_END);
  const blockRegex = new RegExp(`${escapedStart}\\r?\\n[\\s\\S]*?\\r?\\n${escapedEnd}\\r?\\n?`, 'g');
  return content.replace(blockRegex, '');
}

module.exports = {
  KNOWN_HOSTS_BLOCK_START,
  KNOWN_HOSTS_BLOCK_END,
  removeManagedKnownHostsBlock,
};
