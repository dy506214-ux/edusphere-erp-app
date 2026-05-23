const QRCode = require('qrcode');
const crypto = require('crypto');
const { getConfigValue } = require('./configHelper');
// const logger = require('../config/logger');

/**
 * Generates a stable cryptographic signature for the QR payload.
 * High-security HMAC ensure no spoofing is possible.
 */
const getSignature = (userId) => {
  return crypto
    .createHmac('sha256', process.env.JWT_SECRET || 'edusphere_fallback_secret_777')
    .update(userId)
    .digest('hex')
    .substring(0, 16); // 16 chars is enough for school-level security while keeping QR density low
};

/**
 * Generates a base64 PNG QR code encoding the userId with verification signature.
 * Payload: { uid: userId, s: signature, v: 2 }
 * Returns a data URL: "data:image/png;base64,..."
 */
const generateUserQR = async (userId) => {
  const brandColor = await getConfigValue('brand_color', '#1a1a2e');
  
  const payload = JSON.stringify({ 
    uid: userId, 
    s: getSignature(userId),
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
 * Returns userId ONLY IF the cryptographic signature is authentic.
 */
const parseQRPayload = (qrPayload) => {
  try {
    const parsed = JSON.parse(qrPayload);
    if (!parsed || !parsed.uid || !parsed.s) return null;

    // Cryptographic verification
    const expectedSignature = getSignature(parsed.uid);
    if (parsed.s !== expectedSignature) {
        // logger.error(`[SECURITY] Invalid QR Signature detected for user ${parsed.uid}`, { userId: parsed.uid });
        return null;
    }

    return parsed.uid;
  } catch {
    return null;
  }
};

module.exports = { generateUserQR, parseQRPayload };
