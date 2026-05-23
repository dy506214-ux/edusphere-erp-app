const { z } = require('zod');

// Schema for student creation
const createStudentSchema = z.object({
    // User details
    email: z.string().email('Invalid email format').min(1, 'Email is required'),
    password: z.string().min(6, 'Password must be at least 6 characters'),
    firstName: z.string().min(1, 'First name is required'),
    lastName: z.string().min(1, 'Last name is required'),
    phone: z.string().optional(),
    dateOfBirth: z.string().optional().refine(p => !p || !isNaN(Date.parse(p)), { message: 'Invalid date' }),
    gender: z.enum(['MALE', 'FEMALE', 'OTHER']).optional(),
    bloodGroup: z.string().optional(),
    address: z.string().optional(),

    // Student details
    admissionNumber: z.string().min(1, 'Admission number is required'),
    rollNumber: z.string().optional(),
    currentClassId: z.string().uuid('Invalid Class ID'),
    sectionId: z.string().uuid('Invalid Section ID'),
    academicYearId: z.string().uuid('Invalid Academic Year ID'),
    joiningDate: z.string().optional(),
    emergencyContact: z.string().optional(),
    emergencyPhone: z.string().optional(),
    medicalConditions: z.string().optional(),
    allergies: z.string().optional(),
});

// Schema for updating basic info
const updateStudentSchema = createStudentSchema.partial().omit({
    email: true,
    password: true,
    admissionNumber: true,
    academicYearId: true
});

// Schema for the comprehensive register endpoint
const registerStudentSchema = z.object({
    // Basic Details
    firstName: z.string().min(1, 'First name is required'),
    lastName: z.string().optional(),
    email: z.string().email('Invalid email format').optional().or(z.literal('')),
    dateOfBirth: z.string().min(1, 'Date of birth is required'),
    gender: z.enum(['MALE', 'FEMALE', 'OTHER']),
    bloodGroup: z.string().optional(),
    photo: z.string().optional(),
    religion: z.string().optional(),
    caste: z.string().optional(),
    nationality: z.string().optional(),

    // Academic Details
    admissionDate: z.string().optional(),
    classId: z.string().uuid('Invalid Class ID'),
    sectionId: z.string().uuid('Invalid Section ID'),
    academicYearId: z.string().uuid('Invalid Academic Year ID'),
    admissionType: z.string().optional(),
    medium: z.string().optional(),
    previousSchool: z.string().optional(),
    previousClass: z.string().optional(),
    tcNumber: z.string().optional(),
    tcIssueDate: z.string().optional(),
    leavingReason: z.string().optional(),

    // Parent Details
    fatherName: z.string().min(1, 'Father name is required'),
    fatherPhone: z.string().min(1, 'Father phone is required'),
    fatherOccupation: z.string().optional(),
    fatherEmail: z.string().optional(),
    fatherAadhaar: z.string().optional(),
    fatherPan: z.string().optional(),

    motherName: z.string().optional(),
    motherPhone: z.string().optional(),
    motherOccupation: z.string().optional(),
    motherAadhaar: z.string().optional(),
    motherPan: z.string().optional(),

    guardianName: z.string().optional(),
    guardianRelation: z.string().optional(),
    guardianPhone: z.string().optional(),

    // Address
    currentAddress: z.string().optional(),
    permanentAddress: z.string().optional(),
    city: z.string().optional(),
    state: z.string().optional(),
    pincode: z.string().optional(),

    // RFID
    rfidCardUid: z.string().optional(),

    // Fee Details (Optional)
    feeStructureIds: z.array(z.string().uuid()).optional(),
    feeDiscounts: z.record(z.number()).optional(),
    initialPayment: z.object({
        amount: z.number().min(0),
        paymentMode: z.string().optional(),
        transactionId: z.string().optional()
    }).optional()
});

module.exports = {
    createStudentSchema,
    updateStudentSchema,
    registerStudentSchema
};
