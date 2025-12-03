const fs = require('fs');
const path = require('path');

function getApps(dir) {
  if (!fs.existsSync(dir)) return [];
  return fs.readdirSync(dir).filter(f => f.endsWith('.app')).map(f => f.replace(/\.app$/,''));
}

function listAll() {
  const system = getApps('/Applications');
  const user = getApps(path.join(process.env.HOME || '', 'Applications'));
  return Array.from(new Set([...system, ...user])).sort();
}

if (require.main === module) {
  console.log(JSON.stringify(listAll(), null, 2));
}

module.exports = { listAll };
