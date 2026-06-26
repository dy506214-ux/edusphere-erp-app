const { z } = require('zod');

const validate = (schema) => (req, res, next) => {
    try {
        // Parse the request body against the schema
        const parsedData = schema.parse(req.body);

        // Replace req.body with the sanitized/parsed data directly
        req.body = parsedData;

        next();
    } catch (error) {
        // If validation fails, transform Zod errors into our custom structure
        if (error instanceof z.ZodError) {
            const messages = error.errors.map(err => `${err.path.join('.')}: ${err.message}`).join(', ');

            return res.status(400).json({
                status: 'fail',
                message: 'Validation failed',
                errors: messages
            });
        }

        // For non-Zod errors, pass to standard error handler
        next(error);
    }
};

module.exports = validate;
