const fs = require('fs');
const path = require('path');

function getDirSize(dirPath) {
  let size = 0;
  try {
    const files = fs.readdirSync(dirPath);
    for (const file of files) {
      const filePath = path.join(dirPath, file);
      try {
        const stats = fs.lstatSync(filePath);
        if (stats.isDirectory()) {
          size += getDirSize(filePath);
        } else if (stats.isFile()) {
          size += stats.size;
        }
      } catch (err) {}
    }
  } catch (err) {}
  return size;
}

const userHome = 'C:\\Users\\Lenovo';
const targets = [
  path.join(userHome, 'AppData\\Local\\Android'),
  path.join(userHome, 'AppData\\Local\\Google'),
  path.join(userHome, 'AppData\\Local\\pip'),
  path.join(userHome, 'AppData\\Local\\npm-cache'),
  path.join(userHome, 'AppData\\Roaming\\npm-cache'),
  path.join(userHome, '.gemini'),
  path.join(userHome, '.rustup'),
  path.join(userHome, '.cargo'),
];

console.log('Checking more folder sizes on C: drive...');
for (const target of targets) {
  if (fs.existsSync(target)) {
    const sizeBytes = getDirSize(target);
    const sizeGB = (sizeBytes / (1024 * 1024 * 1024)).toFixed(2);
    console.log(`${target}: ${sizeGB} GB`);
  } else {
    console.log(`${target} does not exist.`);
  }
}
