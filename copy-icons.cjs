const fs = require('fs');
const path = require('path');

const resDir = path.join(__dirname, 'android/app/src/main/res');
const densities = ['mipmap-hdpi', 'mipmap-mdpi', 'mipmap-xhdpi', 'mipmap-xxhdpi', 'mipmap-xxxhdpi'];

densities.forEach(density => {
  const dir = path.join(resDir, density);
  const src = path.join(dir, 'ic_launcher.png');
  const dst = path.join(dir, 'ic_launcher_round.png');
  if (fs.existsSync(src)) {
    fs.copyFileSync(src, dst);
    console.log(`✅ Copied/Updated: ${density}/ic_launcher_round.png`);
  } else {
    console.log(`❌ Source missing: ${density}/ic_launcher.png`);
  }
});

console.log('\n✅ Done! All round icons ready.');
