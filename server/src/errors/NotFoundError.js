const AppError = require('./AppError');

/**
 * Custom Error class for Not Found exceptions.
 * Thrown when a requested resource (like a specific user or item) is not found in the DB.
 */
class NotFoundError extends AppError {
    constructor(message = 'Resource not found') {
        super(message, 404);
        this.name = 'NotFoundError';
    }
}

module.exports = NotFoundError;
