-- ==========================================================
-- RBAC Database Script: Permissions & RolePermissions Setup
-- ==========================================================
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- 1. Create Permissions Table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Permissions')
BEGIN
    CREATE TABLE Permissions (
        PermissionId INT IDENTITY(1,1) PRIMARY KEY,
        PermissionKey NVARCHAR(50) NOT NULL UNIQUE,
        ModuleName NVARCHAR(50) NOT NULL,
        DisplayName NVARCHAR(100) NOT NULL,
        Description NVARCHAR(255) NULL
    );
END
GO

-- 2. Create RolePermissions Table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'RolePermissions')
BEGIN
    CREATE TABLE RolePermissions (
        RoleId INT NOT NULL,
        PermissionId INT NOT NULL,
        CONSTRAINT PK_RolePermissions PRIMARY KEY (RoleId, PermissionId),
        CONSTRAINT FK_RolePermissions_Roles FOREIGN KEY (RoleId) REFERENCES Roles(RoleId) ON DELETE CASCADE,
        CONSTRAINT FK_RolePermissions_Permissions FOREIGN KEY (PermissionId) REFERENCES Permissions(PermissionId) ON DELETE CASCADE
    );
END
GO

-- 3. Seed Standard Permissions
MERGE INTO Permissions AS target
USING (VALUES
    -- Overview
    ('DASHBOARD_VIEW', 'Overview', 'View Dashboard', 'Access operational metrics and quick desk shortcuts'),
    
    -- Academic & Batches
    ('ACADEMICS_MANAGE', 'Academic', 'Manage Sessions & Courses', 'Manage academic sessions, courses and subjects'),
    ('BATCHES_MANAGE', 'Academic', 'Manage Batches', 'Create, update and assign teachers to batches'),
    
    -- People & Admissions
    ('REGISTRATIONS_APPROVE', 'People', 'Approve Registrations', 'Review and approve online student & faculty signups'),
    ('CRM_INQUIRIES', 'People', 'Manage CRM Inquiries', 'Capture student inquiries and track admissions leads'),
    ('STUDENTS_MANAGE', 'People', 'Manage Students Directory', 'Create walk-in admissions, edit and manage students'),
    ('TEACHERS_MANAGE', 'People', 'Manage Faculty Staff', 'Manage teachers and faculty records'),
    
    -- Finance & Billing
    ('FEES_MANAGE', 'Finance', 'Manage Student Fees', 'Setup fee structures and monitor due fees'),
    ('PAYMENTS_VERIFY', 'Finance', 'Verify UPI Payments', 'Review student UPI screenshots and confirm receipts'),
    ('EXPENSES_MANAGE', 'Finance', 'Manage Expenses', 'Record and audit institute operations expenses'),
    
    -- Operations & Reports
    ('ATTENDANCE_MANAGE', 'Operations', 'Manage Attendance', 'Institute-wide attendance monitoring and records'),
    ('EXAMS_MANAGE', 'Operations', 'Manage Exams & Marks', 'Schedule exams and record student grading'),
    ('REPORTS_VIEW', 'Operations', 'View Analytics & Reports', 'Export operational, student and financial reports'),
    
    -- Faculty Desk Permissions
    ('FACULTY_BATCHES_VIEW', 'Faculty', 'View My Batches', 'View batches assigned to teacher'),
    ('FACULTY_ATTENDANCE_MARK', 'Faculty', 'Mark Batch Attendance', 'Record daily lecture student attendance'),
    ('FACULTY_EXAM_MARKS', 'Faculty', 'Enter Exam Scores', 'Enter marks for students in teacher batches'),
    
    -- Student Desk Permissions
    ('STUDENT_ATTENDANCE_VIEW', 'Student', 'View My Attendance', 'Check individual attendance records and percentage'),
    ('STUDENT_FEES_PAY', 'Student', 'Pay Fees & View Receipts', 'Pay fees via UPI and download invoices/receipts'),
    ('STUDENT_RESULTS_VIEW', 'Student', 'View Exam Results', 'Access published test results and performance cards'),
    
    -- Profile
    ('PROFILE_MANAGE', 'Profile', 'Manage Own Profile', 'Update personal contact, photo and demographic details')
) AS source (PermissionKey, ModuleName, DisplayName, Description)
ON target.PermissionKey = source.PermissionKey
WHEN MATCHED THEN
    UPDATE SET 
        ModuleName = source.ModuleName,
        DisplayName = source.DisplayName,
        Description = source.Description
WHEN NOT MATCHED THEN
    INSERT (PermissionKey, ModuleName, DisplayName, Description)
    VALUES (source.PermissionKey, source.ModuleName, source.DisplayName, source.Description);
GO

-- 4. Map Permissions to Roles
-- Role 1: Admin gets ALL permissions
INSERT INTO RolePermissions (RoleId, PermissionId)
SELECT 1, PermissionId FROM Permissions
WHERE NOT EXISTS (SELECT 1 FROM RolePermissions WHERE RoleId = 1 AND PermissionId = Permissions.PermissionId);
GO

-- Role 2: Teacher Permissions
INSERT INTO RolePermissions (RoleId, PermissionId)
SELECT 2, PermissionId FROM Permissions
WHERE PermissionKey IN (
    'DASHBOARD_VIEW',
    'FACULTY_BATCHES_VIEW',
    'FACULTY_ATTENDANCE_MARK',
    'FACULTY_EXAM_MARKS',
    'PROFILE_MANAGE'
)
AND NOT EXISTS (SELECT 1 FROM RolePermissions WHERE RoleId = 2 AND PermissionId = Permissions.PermissionId);
GO

-- Role 3: Student Permissions
INSERT INTO RolePermissions (RoleId, PermissionId)
SELECT 3, PermissionId FROM Permissions
WHERE PermissionKey IN (
    'DASHBOARD_VIEW',
    'STUDENT_ATTENDANCE_VIEW',
    'STUDENT_FEES_PAY',
    'STUDENT_RESULTS_VIEW',
    'PROFILE_MANAGE'
)
AND NOT EXISTS (SELECT 1 FROM RolePermissions WHERE RoleId = 3 AND PermissionId = Permissions.PermissionId);
GO

-- 5. Stored Procedure: Get Permissions by User Id
CREATE OR ALTER PROCEDURE sp_GetUserPermissions
    @UserId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET QUOTED_IDENTIFIER ON;

    SELECT DISTINCT p.PermissionKey
    FROM Users u
    INNER JOIN RolePermissions rp ON u.RoleId = rp.RoleId
    INNER JOIN Permissions p ON rp.PermissionId = p.PermissionId
    WHERE u.UserId = @UserId AND u.IsActive = 1;
END;
GO

-- 6. Stored Procedure: Get All Permissions by Role Id
CREATE OR ALTER PROCEDURE sp_GetRolePermissions
    @RoleId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET QUOTED_IDENTIFIER ON;

    SELECT p.PermissionId, p.PermissionKey, p.ModuleName, p.DisplayName, p.Description
    FROM RolePermissions rp
    INNER JOIN Permissions p ON rp.PermissionId = p.PermissionId
    WHERE rp.RoleId = @RoleId
    ORDER BY p.ModuleName, p.DisplayName;
END;
GO
