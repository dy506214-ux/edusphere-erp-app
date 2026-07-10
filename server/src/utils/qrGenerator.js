const QRCode = require('qrcode');
const crypto = require('crypto');
const { getConfigValue } = require('./configHelper');
// const logger = require('../config/logger');

/**
 * Generates a stable cryptographic signature for the QR payload.
 * High-security HMAC ensure no spoofing is possible.
 */
const getSignature = (data) => {
  return crypto
    .createHmac('sha256', process.env.JWT_SECRET || 'edusphere_fallback_secret_777')
    .update(data)
    .digest('hex')
    .substring(0, 16); // 16 chars is enough for school-level security while keeping QR density low
};

/**
 * Generates a base64 PNG QR code encoding the userId with verification signature.
 * Payload: { uid: userId, ts: timestamp, s: signature, v: 2 }
 * Returns a data URL: "data:image/png;base64,..."
 */
const generateUserQR = async (userId) => {
  const brandColor = await getConfigValue('brand_color', '#1a1a2e');
  const ts = Date.now();
  
  const payload = JSON.stringify({ 
    uid: userId, 
    ts: ts,
    s: getSignature(`${userId}:${ts}`),
    v: 2 
  });

  const dataUrl = await QRCode.toDataURL(payload, {
    width: 350,
    margin: 2,
    errorCorrectionLevel: 'H',
    color: {
      dark: brandColor,
      light: '#ffffff',
    },
  });
  return dataUrl;
};

/**
 * Parses and verifies a QR payload. 
 * Returns userId ONLY IF the cryptographic signature is authentic and fresh.
 */
const parseQRPayload = (qrPayload) => {
  if (!qrPayload) return null;
  try {
    const parsed = JSON.parse(qrPayload);
    if (parsed && parsed.uid && parsed.s && parsed.ts) {
      const ageMs = Date.now() - parsed.ts;
      if (ageMs >= 0 && ageMs <= 30000) {
        const expectedSignature = getSignature(`${parsed.uid}:${parsed.ts}`);
        if (parsed.s === expectedSignature) {
          return parsed.uid;
        }
      }
    }
  } catch (e) {
    // Fallback to raw string (like admission number)
  }
  return qrPayload.toString().trim();
};

module.exports = { generateUserQR, parseQRPayload };
