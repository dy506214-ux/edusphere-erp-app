/**
 * Base custom error class for the application.
 * Extends the built-in Error object to include HTTP status codes
 * and operational status (differentiates between operational errors 
 * and programming bugs).
 */
class AppError extends Error {
    constructor(message, statusCode) {
        super(message);

        this.statusCode = statusCode;
        // Set status to 'fail' for 4xx client errors, 'error' for 5xx server errors
        this.status = `${statusCode}`.startsWith('4') ? 'fail' : 'error';
        // isOperational is set to true so we can identify trusted errors 
        // and send message to the client, versus 500 unhandled exceptions.
        this.isOperational = true;

        // Capture the stack trace, keeping the constructor call out of it
        Error.captureStackTrace(this, this.constructor);
    }
}

module.exports = AppError;
