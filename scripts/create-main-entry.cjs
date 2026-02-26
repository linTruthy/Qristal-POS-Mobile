const { writeFileSync } = require('node:fs');
const { join } = require('node:path');

const entrypointPath = join(__dirname, '..', 'dist', 'main.js');
writeFileSync(entrypointPath, "require('./src/main.js');\n", 'utf8');
console.log(`Created ${entrypointPath}`);
