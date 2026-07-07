const fs = require('fs');
const path = require('path');
const filePath = path.join(__dirname, 'nakit akış', 'index.html');
let content = fs.readFileSync(filePath, 'utf8');
content = content.replace(/<style>[\s\S]*?<\/style>/, '<link rel="stylesheet" href="../sapgui.css" />');
fs.writeFileSync(filePath, content, 'utf8');
console.log('✅ Refactored nakit akış index.html successfully!');
