import sharp from 'sharp';

const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630">
  <rect width="1200" height="630" fill="#0a0a0a"/>
  <circle cx="120" cy="120" r="44" fill="#ececec"/>
  <text x="120" y="135" text-anchor="middle" font-family="Helvetica, Arial, sans-serif" font-weight="700" font-size="36" fill="#0a0a0a">EC</text>
  <text x="80" y="330" font-family="Georgia, serif" font-weight="300" font-size="64" fill="#ececec">I build AI that actually works.</text>
  <text x="80" y="395" font-family="Georgia, serif" font-style="italic" font-weight="300" font-size="40" fill="#9aa1ad">Not in labs. Not in theory.</text>
  <text x="80" y="540" font-family="Courier New, monospace" font-size="26" letter-spacing="4" fill="#2fbd8f">ENVER CETIN · DIRECTOR AI, CIKLUM · MUNICH</text>
</svg>`;

await sharp(Buffer.from(svg)).png().toFile('public/og-default.png');
console.log('og-default.png written');

// Apple touch icon (180×180) — same dark-circle "EC" monogram as favicon.svg,
// on a transparent background so iOS applies its own corner mask.
const appleSvg = `<svg xmlns="http://www.w3.org/2000/svg" width="180" height="180" viewBox="0 0 180 180">
  <circle cx="90" cy="90" r="90" fill="#16181d"/>
  <text x="90" y="118" text-anchor="middle" font-family="Helvetica, Arial, sans-serif" font-weight="600" font-size="70" letter-spacing="-3" fill="#fafafa">EC</text>
</svg>`;

await sharp(Buffer.from(appleSvg)).png().toFile('public/apple-touch-icon.png');
console.log('apple-touch-icon.png written');
