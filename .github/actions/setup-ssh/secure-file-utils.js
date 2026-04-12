const fs = require('fs');

const NO_FOLLOW_FLAG = typeof fs.constants.O_NOFOLLOW === 'number' ? fs.constants.O_NOFOLLOW : 0;
const READ_OPEN_FLAGS = fs.constants.O_RDONLY | NO_FOLLOW_FLAG;
const WRITE_OPEN_FLAGS =
  fs.constants.O_WRONLY |
  fs.constants.O_CREAT |
  fs.constants.O_TRUNC |
  NO_FOLLOW_FLAG;

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

function assertSafeRegularFileOrAbsent(filePath, label) {
  if (!fs.existsSync(filePath)) {
    return false;
  }

  assertSafeRegularFile(filePath, label);
  return true;
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

function writeSafeUtf8File(filePath, content, mode, label, defaultMode) {
  const targetMode = typeof mode === 'number' ? mode : defaultMode;

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

module.exports = {
  assertSafeRegularFile,
  assertSafeRegularFileOrAbsent,
  readSafeUtf8File,
  writeSafeUtf8File,
};
