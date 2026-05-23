const AppError = require('./AppError');

/**
 * Custom Error class for Data Validation exceptions.
 * Thrown when bad parameters/body data is received from the client.
 */
class ValidationError extends AppError {
    constructor(message) {
        super(message, 400);
        this.name = 'ValidationError';
    }
}

module.exports = ValidationError;
