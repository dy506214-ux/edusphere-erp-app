const { VALID_ROLES, ROLES } = require('../constants');

/**
 * Validates and normalizes roles for a user.
 * Ensures:
 * 1. All roles are valid system roles.
 * 2. Primary role is included in the roles array.
 * 3. Students only have the STUDENT role.
 * 4. No duplicate roles.
 * 
 * @param {string[]} roles Array of roles
 * @param {string} primaryRole The main role
 * @returns {Object} { valid: boolean, message?: string, roles: string[] }
 */
const validateAndNormalizeRoles = (roles, primaryRole) => {
    if (!primaryRole) {
        return { valid: false, message: 'Primary role is required' };
    }

    if (!VALID_ROLES.includes(primaryRole)) {
        return { valid: false, message: `Invalid primary role: ${primaryRole}` };
    }

    // Merge shared credentials logic: Student always gets STUDENT role
    // This can be expanded if we add more "auto-roles"
    let rolesArray = Array.isArray(roles) && roles.length > 0 ? roles : [primaryRole];

    // Ensure primary role is included
    if (!rolesArray.includes(primaryRole)) {
        rolesArray = [primaryRole, ...rolesArray];
    }

    // Remove duplicates
    rolesArray = [...new Set(rolesArray)];

    // Validate all roles
    for (const r of rolesArray) {
        if (!VALID_ROLES.includes(r)) {
            return { valid: false, message: `Invalid role in array: ${r}` };
        }
    }

    // Students can ONLY have STUDENT role
    if (primaryRole === ROLES.STUDENT && rolesArray.length > 1) {
        return { valid: false, message: 'Students cannot have multiple roles' };
    }

    if (rolesArray.includes(ROLES.STUDENT) && primaryRole !== ROLES.STUDENT) {
        return { valid: false, message: 'If a user has STUDENT role, it must be their primary role' };
    }

    return { 
        valid: true, 
        roles: rolesArray 
    };
};

module.exports = {
    validateAndNormalizeRoles
};
