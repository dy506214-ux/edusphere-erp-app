/**
 * Async Handler Utility
 * 
 * Wraps async functions in Express controllers to automatically catch any
 * rejected promises and pass them to the global error handling middleware using next(err).
 * Removes the need for writing repetitive try/catch blocks in every controller.
 * 
 * @param {Function} fn - The async controller function
 * @returns {Function} - A middleware function
 */
const asyncHandler = (fn) => {
    return (req, res, next) => {
        Promise.resolve(fn(req, res, next)).catch(next);
    };
};

module.exports = asyncHandler;
