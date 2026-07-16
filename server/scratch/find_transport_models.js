const fs = require('fs');
const path = require('path');

const schemaPath = path.join(__dirname, '..', 'prisma', 'schema.prisma');
const content = fs.readFileSync(schemaPath, 'utf8');

const regex = /model\s+(\w+)\s+\{[\s\S]*?\}/g;
let match;
while ((match = regex.exec(content)) !== null) {
  const modelName = match[1];
  if (modelName.toLowerCase().includes('transport') || 
      modelName.toLowerCase().includes('vehicle') || 
      modelName.toLowerCase().includes('route') || 
      modelName.toLowerCase().includes('stop') ||
      modelName.toLowerCase().includes('allocation')) {
    console.log(`--- MODEL: ${modelName} ---`);
    console.log(match[0]);
    console.log('\n');
  }
}
