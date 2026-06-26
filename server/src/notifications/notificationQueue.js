const logger = require('../config/logger');
const redis = require('redis');

let redisClient;
const REDIS_URL = process.env.REDIS_URL;

if (REDIS_URL) {
  redisClient = redis.createClient({ url: REDIS_URL });
  redisClient.on('error', (err) => logger.error('Redis Client Error', err));
  redisClient.connect().catch(err => {
      logger.error('Failed to connect to Redis, notifications will be direct:', err);
      redisClient = null;
  });
} else {
  logger.info('REDIS_URL not configured. Notifications will be processed directly.');
}

/**
 * Add a notification to the system
 * Gracefully handles Redis absence
 */
const addNotification = async (data) => {
  try {
    if (redisClient && redisClient.isOpen) {
      await redisClient.lPush('notification_queue', JSON.stringify(data));
      logger.info('Added notification to Redis queue');
    } else {
      // Fallback: Direct processing (Fire and forget to avoid blocking main thread)
      processNotification(data).catch(err => logger.error('Direct notification error:', err));
    }
  } catch (error) {
    logger.error('Error in addNotification:', error);
    processNotification(data).catch(err => logger.error('Direct notification fallback error:', err));
  }
};

/**
 * Process notification (Email, SMS, App Push) with retry logic
 */
const processNotification = async (data, retryCount = 0) => {
  const MAX_RETRIES = 3;
  
  try {
    // Placeholder for notification delivery logic
    // In a real environment, this would call AWS SES, Twilio, or other providers
    logger.info(`Processing notification attempt ${retryCount + 1}:`, data);
    
    // Simulate periodic delivery failure for testing retry logic
    // if (Math.random() < 0.3) throw new Error('Simulated delivery failure');
    
  } catch (error) {
    if (retryCount < MAX_RETRIES) {
      const delay = Math.pow(2, retryCount) * 1000; // Exponential backoff: 1s, 2s, 4s
      logger.warn(`Notification failed (retry ${retryCount + 1}/${MAX_RETRIES}). Retrying in ${delay}ms... Error: ${error.message}`);
      
      setTimeout(() => {
        processNotification(data, retryCount + 1);
      }, delay);
    } else {
      logger.error(`Critical: Notification delivery failed after ${MAX_RETRIES} retries. Data:`, data);
    }
  }
};

module.exports = {
  addNotification,
  processNotification
};
