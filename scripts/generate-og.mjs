import sharp from 'sharp';

const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630">
  <rect width="1200" height="630" fill="#0a0a0a"/>
  <circle cx="120" cy="120" r="44" fill="#ececec"/>
  <text x="120" y="135" text-anchor="middle" font-family="Helvetica, Arial, sans-serif" font-weight="700" font-size="36" fill="#0a0a0a">EC</text>
  <text x="80" y="330" font-family="Georgia, serif" font-weight="300" font-size="64" fill="#ececec">I build AI that actually works.</text>
  <text x="80" y="395" font-family="Georgia, serif" font-style="italic" font-weight="300" font-size="40" fill="#9aa1ad">Not in labs. Not in theory.</text>
  <text x="80" y="540" font-family="Courier New, monospace" font-size="26" letter-spacing="4" fill="#2fbd8f">ENVER CETIN — DIRECTOR AI, CIKLUM · MUNICH</text>
</svg>`;

await sharp(Buffer.from(svg)).png().toFile('public/og-default.png');
console.log('og-default.png written');
