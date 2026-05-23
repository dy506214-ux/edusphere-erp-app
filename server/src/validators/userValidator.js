const { z } = require('zod');

/**
 * Validator schemas for User / Auth related routes
 */

// Schema for user registration
const registerSchema = z.object({
    email: z.string().email('Invalid email format').min(1, 'Email is required'),
    password: z.string().min(6, 'Password must be at least 6 characters'),
    firstName: z.string().min(1, 'First name is required'),
    lastName: z.string().min(1, 'Last name is required'),
    role: z.enum([
        'SUPER_ADMIN', 'ADMIN', 'TEACHER', 'STUDENT', 'PARENT', 
        'ACCOUNTANT', 'LIBRARIAN', 'INVENTORY_MANAGER', 'HR_MANAGER', 'ADMISSION_MANAGER'
    ]).optional(),
    roles: z.array(z.string()).optional(),
    phone: z.string().optional(),
});

// Schema for user login
const loginSchema = z.object({
    email: z.string().email('Invalid email format').min(1, 'Email is required'),
    password: z.string().min(1, 'Password is required'),
});

// Schema for password reset
const resetPasswordSchema = z.object({
    password: z.string().min(6, 'New password must be at least 6 characters'),
});

// Schema for HR employee creation (extended user)
const hrCreateEmployeeSchema = z.object({
    firstName: z.string().min(1, 'First name is required'),
    lastName: z.string().min(1, 'Last name is required'),
    email: z.string().email('Invalid email format'),
    password: z.string().min(6, 'Password is required'),
    phone: z.string().optional(),
    gender: z.enum(['MALE', 'FEMALE', 'OTHER']).optional(),
    address: z.string().optional(),
    dateOfBirth: z.string().optional(),
    role: z.string().optional(),
    qualification: z.string().optional(),
    experience: z.union([z.string(), z.number()]).optional(),
    specialization: z.string().optional(),
    joiningDate: z.string().optional(),
    designation: z.string().optional(),
    department: z.string().optional(),
    assignedScannerId: z.string().optional(),
});

module.exports = {
    registerSchema,
    loginSchema,
    resetPasswordSchema,
    hrCreateEmployeeSchema
};
