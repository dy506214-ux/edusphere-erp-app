const prisma = require('../config/database');
const bcrypt = require('bcrypt');
const { generateUserQR, parseQRPayload } = require('../utils/qrGenerator');
const { VALID_ROLES } = require('../constants');
const asyncHandler = require('../utils/asyncHandler');
const logger = require('../config/logger');
const { validateAndNormalizeRoles } = require('../utils/userUtils');

/**
 * Role Validation Rules
 * - Students can ONLY have STUDENT role (no multi-role allowed)
 * - All other users can have multiple roles
 * - ADMIN represents the Principal with full access
 */

// validateRoles removed - now using validateAndNormalizeRoles from userUtils

/**
 * Get all users with filtering and pagination
 */
const getAllUsers = asyncHandler(async (req, res) => {
    const {
      page = 1,
      limit = 20,
      role,
      search,
      isActive,
      sortBy = 'createdAt',
      sortOrder = 'desc'
    } = req.query;

    const skip = (parseInt(page) - 1) * parseInt(limit);
    const take = parseInt(limit);

    // Build where clause
    const where = {};
    const andConditions = [];

    // Role filter (can filter by primary role or any role in roles array)
    if (role) {
      andConditions.push({
        OR: [
          { role: role },
          { roles: { has: role } }
        ]
      });
    }

    // Search filter
    if (search) {
      andConditions.push({
        OR: [
          { email: { contains: search, mode: 'insensitive' } },
          { firstName: { contains: search, mode: 'insensitive' } },
          { lastName: { contains: search, mode: 'insensitive' } },
          { username: { contains: search, mode: 'insensitive' } }
        ]
      });
    }

    // Active status filter
    if (isActive !== undefined) {
      where.isActive = isActive === 'true';
    }

    // Combine conditions
    if (andConditions.length > 0) {
      where.AND = andConditions;
    }

    // Get users with pagination
    const [users, total] = await Promise.all([
      prisma.user.findMany({
        where,
        skip,
        take,
        orderBy: { [sortBy]: sortOrder },
        select: {
          id: true,
          email: true,
          username: true,
          firstName: true,
          lastName: true,
          phone: true,
          avatar: true,
          role: true,
          roles: true,
          isActive: true,
          emailVerified: true,
          lastLogin: true,
          createdAt: true,
          updatedAt: true,
          // Include role-specific data with relationships
          student: {
            select: {
              id: true,
              admissionNumber: true,
              status: true,
              parents: {
                select: {
                  id: true,
                  relationship: true,
                  parent: {
                    select: {
                      id: true,
                      email: true,
                      firstName: true,
                      lastName: true
                    }
                  }
                }
              }
            }
          },
          teacher: {
            select: {
              id: true,
              employeeId: true
            }
          },
          staff: {
            select: {
              id: true,
              employeeId: true,
              designation: true
            }
          }
          // NOTE: Parent removed - parents don't have user accounts
          // Parents are standalone records linked to students via StudentParent table
        }
      }),
      prisma.user.count({ where })
    ]);

    // Enhance users with relationship info and roles
    const usersWithRoles = users.map(user => {
      const baseUser = {
        ...user,
        roles: user.roles && user.roles.length > 0 ? user.roles : [user.role]
      };

      // Add relationship metadata for UI display
      const relationships = [];

      // For students with parents - show parent linkage
      if (user.student && user.student.parents && user.student.parents.length > 0) {
        relationships.push({
          type: 'HAS_PARENT',
          count: user.student.parents.length,
          details: user.student.parents.map(sp => ({
            parentId: sp.parent.id,
            relationship: sp.relationship,
            parentName: `${sp.parent.firstName} ${sp.parent.lastName}`,
            parentEmail: sp.parent.email,
            sharedCredentials: true // This student's credentials work for parent login
          }))
        });
      }

      if (relationships.length > 0) {
        baseUser.relationships = relationships;
      }

      return baseUser;
    });

    res.json({
      success: true,
      users: usersWithRoles,
      pagination: {
        total,
        page: parseInt(page),
        limit: parseInt(limit),
        totalPages: Math.ceil(total / parseInt(limit))
      }
    });
});

/**
 * Get single user by ID
 */
const getUserById = asyncHandler(async (req, res) => {
    const { id } = req.params;

    // Permissions: Admins can view any user, others can only view themselves
    const userRoles = req.user.roles || [req.user.role];
    const isAdmin = userRoles.some(r => ['SUPER_ADMIN', 'ADMIN'].includes(r));
    
    if (!isAdmin && req.user.userId !== id) {
        return res.status(403).json({
            success: false,
            message: 'Access denied: You can only view your own profile'
        });
    }

    const user = await prisma.user.findUnique({
      where: { id },
      select: {
        id: true,
        email: true,
        username: true,
        firstName: true,
        lastName: true,
        phone: true,
        avatar: true,
        dateOfBirth: true,
        gender: true,
        bloodGroup: true,
        address: true,
        role: true,
        roles: true,
        isActive: true,
        emailVerified: true,
        lastLogin: true,
        lastPasswordChange: true,
        createdAt: true,
        updatedAt: true,
        qrCode: true,
        student: {
          include: {
            currentClass: true,
            section: true,
            academicYear: true
          }
        },
        teacher: {
          include: {
            subjects: {
              include: {
                subject: true
              }
            }
          }
        },
        staff: true
        // NOTE: Parent removed - parents don't have user accounts
      }
    });

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }

    res.json({
      success: true,
      user
    });
});

/**
 * Create a new user (general purpose, not role-specific)
 */
const createUser = asyncHandler(async (req, res) => {
    const {
      email,
      password,
      firstName,
      lastName,
      phone,
      username,
      role,
      roles = []
    } = req.body;

    // Validation
    if (!email || !password || !firstName || !lastName || !role) {
      return res.status(400).json({
        success: false,
        message: 'Email, password, firstName, lastName, and role are required'
      });
    }

    // Use centralized role validation & normalization
    const roleCheck = validateAndNormalizeRoles(roles, role);
    if (!roleCheck.valid) {
      return res.status(400).json({
        success: false,
        message: roleCheck.message
      });
    }

    const { roles: userRoles } = roleCheck;

    // Check if email already exists
    const existingUser = await prisma.user.findUnique({
      where: { email }
    });

    if (existingUser) {
      return res.status(400).json({
        success: false,
        message: 'Email already exists'
      });
    }

    // Check if username exists (if provided)
    if (username) {
      const existingUsername = await prisma.user.findUnique({
        where: { username }
      });

      if (existingUsername) {
        return res.status(400).json({
          success: false,
          message: 'Username already exists'
        });
      }
    }

    // Hash password
    const hashedPassword = await bcrypt.hash(password, 10);

    // Create user
    const user = await prisma.user.create({
      data: {
        email,
        password: hashedPassword,
        firstName,
        lastName,
        phone,
        username,
        role,
        roles: userRoles
      },
      select: {
        id: true,
        email: true,
        username: true,
        firstName: true,
        lastName: true,
        phone: true,
        role: true,
        roles: true,
        isActive: true,
        emailVerified: true,
        createdAt: true
      }
    });

    // Generate QR code for the new user and save it
    try {
      const qrCode = await generateUserQR(user.id);
      await prisma.user.update({ where: { id: user.id }, data: { qrCode } });
      user.qrCode = qrCode;
    } catch (qrErr) {
      logger.error(`QR generation failed (non-fatal): ${qrErr.message}`);
    }

    res.status(201).json({
      success: true,
      message: 'User created successfully',
      user
    });
});

/**
 * Get a user's QR code image
 * GET /api/users/:id/qr
 */
const getUserQR = asyncHandler(async (req, res) => {
    const { id } = req.params;

    // Permission: user can fetch their own QR, admins can fetch any
    const userRoles = req.user.roles || [req.user.role];
    const isAdmin = userRoles.some(r => ['SUPER_ADMIN', 'ADMIN'].includes(r));
    if (!isAdmin && req.user.userId !== id) {
      return res.status(403).json({ success: false, message: 'Access denied' });
    }

    const user = await prisma.user.findUnique({
      where: { id },
      select: { id: true, firstName: true, lastName: true, role: true, qrCode: true }
    });

    if (!user) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }

    // Lazily generate QR if missing (e.g. legacy users created before this feature)
    if (!user.qrCode) {
      const qrCode = await generateUserQR(id);
      await prisma.user.update({ where: { id }, data: { qrCode } });
      user.qrCode = qrCode;
    }

    res.json({ success: true, qrCode: user.qrCode, user: { id: user.id, firstName: user.firstName, lastName: user.lastName, role: user.role } });
});

/**
 * Regenerate a user's QR code (admin only)
 * POST /api/users/:id/qr/regenerate
 */
const regenerateUserQR = asyncHandler(async (req, res) => {
    const { id } = req.params;

    // Permissions check
    const userRoles = req.user.roles || [req.user.role];
    const isAdmin = userRoles.some(r => ['SUPER_ADMIN', 'ADMIN'].includes(r));
    if (!isAdmin) {
      return res.status(403).json({ success: false, message: 'Only administrators can regenerate QR codes' });
    }

    const user = await prisma.user.findUnique({ where: { id }, select: { id: true, qrIssued: true } });
    if (!user) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }

    if (user.qrIssued) {
      return res.status(403).json({ 
        success: false, 
        message: 'This Digital ID is marked as "Issued" and cannot be regenerated. Please unlock it first.' 
      });
    }

    const qrCode = await generateUserQR(id);
    await prisma.user.update({ where: { id }, data: { qrCode } });

    res.json({ success: true, message: 'QR code regenerated successfully', qrCode });
});

/**
 * Toggle the "Issued" status of a user's QR code
 * POST /api/users/:id/qr/status
 */
const toggleQRIssued = asyncHandler(async (req, res) => {
    const { id } = req.params;
    const { issued } = req.body; // boolean

    // Only administrators can toggle issued status
    const userRoles = req.user.roles || [req.user.role];
    const isAdmin = userRoles.some(r => ['SUPER_ADMIN', 'ADMIN'].includes(r));
    if (!isAdmin) {
      return res.status(403).json({ success: false, message: 'Only administrators can toggle Digital ID status' });
    }

    const user = await prisma.user.findUnique({ where: { id } });
    if (!user) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }

    const updatedUser = await prisma.user.update({
      where: { id },
      data: {
        qrIssued: issued,
        qrIssuedAt: issued ? new Date() : null
      },
      select: { id: true, qrIssued: true, qrIssuedAt: true }
    });

    res.json({
      success: true,
      message: `Digital ID ${issued ? 'locked (marked as issued)' : 'unlocked'} successfully`,
      qrIssued: updatedUser.qrIssued,
      qrIssuedAt: updatedUser.qrIssuedAt
    });
});

/**
 * Update user details
 */
const updateUser = asyncHandler(async (req, res) => {
    const { id } = req.params;
    const {
      firstName,
      lastName,
      phone,
      username,
      dateOfBirth,
      gender,
      bloodGroup,
      address,
      role,
      roles,
      isActive,
      emailVerified
    } = req.body;

    // Check if user exists
    const existingUser = await prisma.user.findUnique({
      where: { id },
      include: {
        student: true
      }
    });

    if (!existingUser) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }

    // Build update data
    const updateData = {};

    if (firstName !== undefined) updateData.firstName = firstName;
    if (lastName !== undefined) updateData.lastName = lastName;
    if (phone !== undefined) updateData.phone = phone;
    if (username !== undefined) updateData.username = username;
    if (dateOfBirth !== undefined) updateData.dateOfBirth = new Date(dateOfBirth);
    if (gender !== undefined) updateData.gender = gender;
    if (bloodGroup !== undefined) updateData.bloodGroup = bloodGroup;
    if (address !== undefined) updateData.address = address;
    if (isActive !== undefined) updateData.isActive = isActive;
    if (emailVerified !== undefined) updateData.emailVerified = emailVerified;

    // Handle role updates
    if (role !== undefined || roles !== undefined) {
      const newPrimaryRole = role || existingUser.role;
      const newRoles = roles || existingUser.roles || [newPrimaryRole];

      // Use centralized role validation & normalization
      const roleCheck = validateAndNormalizeRoles(roles || [newPrimaryRole], newPrimaryRole);
      if (!roleCheck.valid) {
        return res.status(400).json({
          success: false,
          message: roleCheck.message
        });
      }

      updateData.role = newPrimaryRole;
      updateData.roles = roleCheck.roles;

      // Special check: If user is a student, cannot change to multi-role
      if (existingUser.student && newRoles.length > 1) {
        return res.status(400).json({
          success: false,
          message: 'Students cannot have multiple roles'
        });
      }

      updateData.role = newPrimaryRole;
      updateData.roles = newRoles;
    }

    // Update user
    const updatedUser = await prisma.user.update({
      where: { id },
      data: updateData,
      select: {
        id: true,
        email: true,
        username: true,
        firstName: true,
        lastName: true,
        phone: true,
        avatar: true,
        dateOfBirth: true,
        gender: true,
        bloodGroup: true,
        address: true,
        role: true,
        roles: true,
        isActive: true,
        emailVerified: true,
        lastLogin: true,
        createdAt: true,
        updatedAt: true
      }
    });

    res.json({
      success: true,
      message: 'User updated successfully',
      user: updatedUser
    });
});

/**
 * Delete user (soft delete by setting isActive to false)
 */
const deleteUser = asyncHandler(async (req, res) => {
    const { id } = req.params;

    // Check if user exists
    const user = await prisma.user.findUnique({
      where: { id }
    });

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }

    // Soft delete
    await prisma.user.update({
      where: { id },
      data: { isActive: false }
    });

    res.json({
      success: true,
      message: 'User deactivated successfully'
    });
});

/**
 * Update user roles (for multi-role assignment)
 */
const updateUserRoles = asyncHandler(async (req, res) => {
    const { id } = req.params;
    const { roles, primaryRole } = req.body;

    if (!roles || !Array.isArray(roles) || roles.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'Roles array is required and must not be empty'
      });
    }

    // Check if user exists
    const existingUser = await prisma.user.findUnique({
      where: { id },
      include: {
        student: true
      }
    });

    if (!existingUser) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }

    // Determine primary role
    const newPrimaryRole = primaryRole || roles[0];

    // Use centralized role validation & normalization
    const roleCheck = validateAndNormalizeRoles(roles, newPrimaryRole);
    if (!roleCheck.valid) {
      return res.status(400).json({
        success: false,
        message: roleCheck.message
      });
    }

    // Special check for students
    if (existingUser.student && (roles.length > 1 || roles[0] !== 'STUDENT')) {
      return res.status(400).json({
        success: false,
        message: 'Students can only have the STUDENT role'
      });
    }

    // updateRoles
    const updatedUser = await prisma.user.update({
      where: { id },
      data: {
        role: newPrimaryRole,
        roles: roleCheck.roles
      },
      select: {
        id: true,
        email: true,
        firstName: true,
        lastName: true,
        role: true,
        roles: true
      }
    });

    res.json({
      success: true,
      message: 'User roles updated successfully',
      user: updatedUser
    });
});

/**
 * Get users by role
 */
const getUsersByRole = asyncHandler(async (req, res) => {
    const { role } = req.params;

    if (!VALID_ROLES.includes(role)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid role'
      });
    }

    const users = await prisma.user.findMany({
      where: {
        OR: [
          { role: role },
          { roles: { has: role } }
        ],
        isActive: true
      },
      select: {
        id: true,
        email: true,
        firstName: true,
        lastName: true,
        phone: true,
        role: true,
        roles: true,
        createdAt: true
      },
      orderBy: {
        firstName: 'asc'
      }
    });

    res.json({
      success: true,
      users,
      count: users.length
    });
});

/**
 * Admin Reset Password
 */
const resetPassword = asyncHandler(async (req, res) => {
    const { id } = req.params;
    const { password } = req.body;

    if (!password || password.length < 6) {
      return res.status(400).json({
        success: false,
        message: 'Password must be at least 6 characters long'
      });
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    await prisma.user.update({
      where: { id },
      data: {
        password: hashedPassword,
        lastPasswordChange: new Date()
      }
    });

    res.json({
      success: true,
      message: 'Password reset successfully'
    });
});

const { uploadToCloudinary, deleteFromCloudinary } = require('../config/cloudinary');
const multer = require('multer');
const fs = require('fs');

const upload = multer({
  dest: 'uploads/temp/',
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB
}).single('avatar');

/**
 * Middleware for profile picture upload
 */
const uploadProfilePicture = (req, res, next) => {
  upload(req, res, (err) => {
    if (err) return res.status(400).json({ success: false, message: err.message });
    next();
  });
};

/**
 * Update user profile picture (avatar)
 */
const updateProfilePicture = asyncHandler(async (req, res) => {
    const { id } = req.params;

    if (!req.file) {
      return res.status(400).json({ success: false, message: 'No image uploaded' });
    }

    // Check permissions: User can update own, or Admin/SuperAdmin
    const userRoles = req.user.roles || [req.user.role];
    const isAdminRole = userRoles.some(r => ['SUPER_ADMIN', 'ADMIN'].includes(r));
    if (!isAdminRole && req.user.userId !== id) {
      fs.unlinkSync(req.file.path);
      return res.status(403).json({ success: false, message: 'Access denied' });
    }

    const user = await prisma.user.findUnique({ where: { id } });
    if (!user) {
      fs.unlinkSync(req.file.path);
      return res.status(404).json({ success: false, message: 'User not found' });
    }

    // Upload to Cloudinary
    const folder = `edusphere/users/${id}/avatar`;
    const result = await uploadToCloudinary(req.file.path, folder);

    // If existing avatar was on Cloudinary, optionally delete it
    // For now, let's just update the URL
    const updatedUser = await prisma.user.update({
      where: { id },
      data: { avatar: result.secure_url },
      select: { id: true, email: true, firstName: true, lastName: true, avatar: true }
    });

    // Clean up temp file
    fs.unlinkSync(req.file.path);

    res.json({
      success: true,
      message: 'Profile picture updated successfully',
      user: updatedUser
    });
});

module.exports = {
  getAllUsers,
  getUserById,
  createUser,
  updateUser,
  deleteUser,
  updateUserRoles,
  getUsersByRole,
  resetPassword,
  updateProfilePicture,
  uploadProfilePicture,
  getUserQR,
  regenerateUserQR,
  toggleQRIssued,
  changePassword: asyncHandler(async (req, res) => {
    const id = req.user.userId;
    const { oldPassword, newPassword, confirmPassword } = req.body;

    if (!oldPassword || !newPassword || !confirmPassword) {
      return res.status(400).json({ success: false, message: 'All password fields are required' });
    }

    if (newPassword !== confirmPassword) {
      return res.status(400).json({ success: false, message: 'New passwords do not match' });
    }

    if (newPassword.length < 6) {
      return res.status(400).json({ success: false, message: 'New password must be at least 6 characters long' });
    }

    const user = await prisma.user.findUnique({ where: { id } });
    if (!user) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }

    // Verify old password
    const isMatched = await bcrypt.compare(oldPassword, user.password);
    if (!isMatched) {
      return res.status(400).json({ success: false, message: 'Invalid current password' });
    }

    // Hash new password
    const hashedPassword = await bcrypt.hash(newPassword, 10);

    await prisma.user.update({
      where: { id },
      data: {
        password: hashedPassword,
        lastPasswordChange: new Date(),
      },
    });

    logger.info(`Password changed for user ${id}`);

    res.json({
      success: true,
      message: 'Password changed successfully',
    });
  }),
};
