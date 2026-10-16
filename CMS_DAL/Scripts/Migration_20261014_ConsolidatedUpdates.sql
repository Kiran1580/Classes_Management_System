-- ====================================================================================================
-- MIGRATION SCRIPT: Consolidated Live Production Database Updates
-- Date: 2026-10-14
-- Database: ClassesManagementDb
--
-- Description:
--   Consolidates all database changes made across the 7 modified/added SQL script files into
--   a single, production-ready, idempotent master script for live server execution.
--
-- Included Sections:
--   1. Schema Adjustments & Safe Constraints (Students.UserId nullability & filtered unique index)
--   2. RBAC Permissions & Role Mapping Setup (Permissions, RolePermissions tables & seed data)
--   3. RBAC Lookup Stored Procedures (sp_GetUserPermissions, sp_GetRolePermissions)
--   4. User Registration & Approval Stored Procedures (sp_RegisterStudent, sp_RegisterTeacher,
--      sp_GetPendingRegistrations, sp_ApproveUser, sp_RejectUser)
--   5. Course & Subject Stored Procedures (sp_GetAllCourses, sp_GetActiveCourses,
--      sp_DeleteCourse, sp_DeleteSubject)
--   6. Batch Management Stored Procedures (sp_DeleteBatch)
--   7. Student Management Stored Procedures (sp_GetNextAdmissionNumber, sp_GetBatchesByCourse,
--      sp_GetStudentStats, sp_GetPagedStudents, sp_GetStudentById, sp_GetStudentByUserId,
--      sp_UpdateStudentProfile, sp_CreateStudentAdmission, sp_UpdateStudent, sp_DeleteOrDeactivateStudent)
--   8. Teacher Management Stored Procedures (sp_GetNextEmployeeCode, sp_GetTeacherStats,
--      sp_GetPagedTeachers, sp_GetTeacherById, sp_GetTeacherByUserId, sp_GetTeacherBatches,
--      sp_CreateTeacher, sp_UpdateTeacher, sp_DeleteTeacher, sp_GetAllActiveTeachers)
--   9. Post-Migration Verification & Diagnostics
-- ====================================================================================================

-- USE ClassesManagementDb; -- (Commented out: Cloud hostings like MonsterASP.NET execute directly in current assigned DB e.g. db73323)


SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

PRINT '>>> [START] Executing Migration_20261014_ConsolidatedUpdates...';
GO

-- ====================================================================================================
-- 1. SCHEMA ADJUSTMENTS & SAFE CONSTRAINTS
-- ====================================================================================================
PRINT '>>> 1. Checking and adjusting Students table schema for walk-in admissions...';

-- A. Ensure Students.UserId is nullable for walk-in admissions (which do not require immediate login account)
IF EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS 
    WHERE TABLE_NAME = 'Students' AND COLUMN_NAME = 'UserId' AND IS_NULLABLE = 'NO'
)
BEGIN
    ALTER TABLE Students ALTER COLUMN UserId INT NULL;
    PRINT '    - Column Students.UserId altered to NULL.';
END
ELSE
BEGIN
    PRINT '    - Column Students.UserId is already nullable.';
END
GO

-- B. Drop legacy non-filtered unique constraint on Students(UserId) if it exists
--    (Standard UNIQUE constraint prevents multiple NULL values in SQL Server)
IF EXISTS (
    SELECT 1 FROM sys.indexes i
    INNER JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
    INNER JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
    WHERE i.object_id = OBJECT_ID('Students') AND c.name = 'UserId' AND i.is_unique = 1 AND i.has_filter = 0
)
BEGIN
    DECLARE @ConstraintName NVARCHAR(128);
    SELECT TOP 1 @ConstraintName = i.name 
    FROM sys.indexes i
    INNER JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
    INNER JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
    WHERE i.object_id = OBJECT_ID('Students') AND c.name = 'UserId' AND i.is_unique = 1 AND i.has_filter = 0;

    IF @ConstraintName IS NOT NULL
    BEGIN
        DECLARE @DropSql NVARCHAR(MAX) = 'ALTER TABLE Students DROP CONSTRAINT [' + @ConstraintName + '];';
        EXEC sp_executesql @DropSql;
        PRINT '    - Legacy non-filtered unique constraint [' + @ConstraintName + '] dropped from Students(UserId).';
    END
END
GO

-- C. Create Filtered Unique Index on Students(UserId) WHERE UserId IS NOT NULL
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes 
    WHERE name = 'UQ_Students_UserId' AND object_id = OBJECT_ID('Students')
)
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX UQ_Students_UserId 
    ON Students(UserId) 
    WHERE UserId IS NOT NULL;
    PRINT '    - Filtered unique index UQ_Students_UserId created.';
END
ELSE
BEGIN
    PRINT '    - Filtered unique index UQ_Students_UserId already exists.';
END
GO


-- ====================================================================================================
-- 2. RBAC PERMISSIONS & ROLE MAPPINGS SETUP
-- ====================================================================================================
PRINT '>>> 2. Setting up RBAC Tables and Permissions Seed Data...';

-- A. Create Permissions Table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Permissions')
BEGIN
    CREATE TABLE Permissions (
        PermissionId INT IDENTITY(1,1) PRIMARY KEY,
        PermissionKey NVARCHAR(50) NOT NULL UNIQUE,
        ModuleName NVARCHAR(50) NOT NULL,
        DisplayName NVARCHAR(100) NOT NULL,
        Description NVARCHAR(255) NULL
    );
    PRINT '    - Permissions table created.';
END
ELSE
BEGIN
    PRINT '    - Permissions table already exists.';
END
GO

-- B. Create RolePermissions Table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'RolePermissions')
BEGIN
    CREATE TABLE RolePermissions (
        RoleId INT NOT NULL,
        PermissionId INT NOT NULL,
        CONSTRAINT PK_RolePermissions PRIMARY KEY (RoleId, PermissionId),
        CONSTRAINT FK_RolePermissions_Roles FOREIGN KEY (RoleId) REFERENCES Roles(RoleId) ON DELETE CASCADE,
        CONSTRAINT FK_RolePermissions_Permissions FOREIGN KEY (PermissionId) REFERENCES Permissions(PermissionId) ON DELETE CASCADE
    );
    PRINT '    - RolePermissions table created.';
END
ELSE
BEGIN
    PRINT '    - RolePermissions table already exists.';
END
GO

-- C. Seed Standard Permissions (Idempotent MERGE)
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
PRINT '    - Standard Permissions merged successfully.';
GO

-- D. Map Permissions to Roles
-- Role 1: Admin gets ALL permissions
INSERT INTO RolePermissions (RoleId, PermissionId)
SELECT 1, PermissionId FROM Permissions
WHERE NOT EXISTS (SELECT 1 FROM RolePermissions WHERE RoleId = 1 AND PermissionId = Permissions.PermissionId);

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
PRINT '    - Role permissions mapped successfully.';
GO


-- ====================================================================================================
-- 3. RBAC LOOKUP STORED PROCEDURES
-- ====================================================================================================
PRINT '>>> 3. Deploying RBAC Lookup Procedures...';
GO

-- 3.1 Get Permissions by User Id
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

-- 3.2 Get All Permissions by Role Id
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


-- ====================================================================================================
-- 4. USER REGISTRATION & APPROVAL STORED PROCEDURES
-- ====================================================================================================
PRINT '>>> 4. Deploying User Registration & Approval Procedures...';
GO

-- 4.1 Register Student (Public Online Registration)
CREATE OR ALTER PROCEDURE sp_RegisterStudent
    @FullName NVARCHAR(100),
    @Email NVARCHAR(100),
    @Mobile NVARCHAR(20) = NULL,
    @PasswordHash NVARCHAR(255),
    @ParentName NVARCHAR(100) = NULL,
    @ParentMobile NVARCHAR(20) = NULL,
    @Gender NVARCHAR(10) = NULL,
    @DateOfBirth DATE = NULL,
    @Address NVARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET QUOTED_IDENTIFIER ON;
    
    -- Check if email exists
    IF EXISTS (SELECT 1 FROM Users WHERE LOWER(Email) = LOWER(LTRIM(RTRIM(@Email))))
    BEGIN
        SELECT -1 AS UserId; -- Email already exists
        RETURN;
    END

    -- Check if mobile exists (if provided)
    IF @Mobile IS NOT NULL AND LTRIM(RTRIM(@Mobile)) <> '' AND EXISTS (SELECT 1 FROM Users WHERE Mobile = LTRIM(RTRIM(@Mobile)))
    BEGIN
        SELECT -2 AS UserId; -- Mobile already exists
        RETURN;
    END

    BEGIN TRANSACTION;
    BEGIN TRY
        -- Insert into Users (RoleId = 3 for Student, IsActive = 0 for pending approval)
        INSERT INTO Users (FullName, Email, Mobile, PasswordHash, RoleId, IsActive, CreatedAt)
        VALUES (LTRIM(RTRIM(@FullName)), LOWER(LTRIM(RTRIM(@Email))), NULLIF(LTRIM(RTRIM(@Mobile)), ''), @PasswordHash, 3, 0, GETDATE());

        DECLARE @NewUserId INT = SCOPE_IDENTITY();

        -- Split FullName into FirstName and LastName
        DECLARE @FirstName NVARCHAR(50);
        DECLARE @LastName NVARCHAR(50);
        DECLARE @SpaceIndex INT = CHARINDEX(' ', LTRIM(RTRIM(@FullName)));

        IF @SpaceIndex > 0
        BEGIN
            SET @FirstName = SUBSTRING(LTRIM(RTRIM(@FullName)), 1, @SpaceIndex - 1);
            SET @LastName = SUBSTRING(LTRIM(RTRIM(@FullName)), @SpaceIndex + 1, 50);
        END
        ELSE
        BEGIN
            SET @FirstName = LTRIM(RTRIM(@FullName));
            SET @LastName = '-';
        END

        -- Generate Admission No (e.g. STU2026-0001)
        DECLARE @AdmissionNo NVARCHAR(50) = 'STU' + CAST(YEAR(GETDATE()) AS NVARCHAR(4)) + '-' + RIGHT('0000' + CAST(@NewUserId AS NVARCHAR(10)), 4);

        -- Insert into Students
        INSERT INTO Students (UserId, AdmissionNo, FirstName, LastName, Gender, DateOfBirth, Mobile, Email, Address, ParentName, ParentMobile, AdmissionDate, IsActive, CreatedAt)
        VALUES (@NewUserId, @AdmissionNo, @FirstName, @LastName, @Gender, @DateOfBirth, NULLIF(LTRIM(RTRIM(@Mobile)), ''), LOWER(LTRIM(RTRIM(@Email))), @Address, NULLIF(LTRIM(RTRIM(@ParentName)), ''), NULLIF(LTRIM(RTRIM(@ParentMobile)), ''), CAST(GETDATE() AS DATE), 0, GETDATE());

        COMMIT TRANSACTION;
        SELECT @NewUserId AS UserId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SELECT 0 AS UserId; -- Failure
    END CATCH
END;
GO

-- 4.2 Register Teacher (Public Online Registration)
CREATE OR ALTER PROCEDURE sp_RegisterTeacher
    @FullName NVARCHAR(100),
    @Email NVARCHAR(100),
    @Mobile NVARCHAR(20) = NULL,
    @PasswordHash NVARCHAR(255),
    @Qualification NVARCHAR(100) = NULL,
    @SubjectSpecialization NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET QUOTED_IDENTIFIER ON;

    -- Check if email exists
    IF EXISTS (SELECT 1 FROM Users WHERE LOWER(Email) = LOWER(LTRIM(RTRIM(@Email))))
    BEGIN
        SELECT -1 AS UserId; -- Email exists
        RETURN;
    END

    -- Check if mobile exists (if provided)
    IF @Mobile IS NOT NULL AND LTRIM(RTRIM(@Mobile)) <> '' AND EXISTS (SELECT 1 FROM Users WHERE Mobile = LTRIM(RTRIM(@Mobile)))
    BEGIN
        SELECT -2 AS UserId; -- Mobile exists
        RETURN;
    END

    BEGIN TRANSACTION;
    BEGIN TRY
        -- Insert into Users (RoleId = 2 for Teacher, IsActive = 0 for pending approval)
        INSERT INTO Users (FullName, Email, Mobile, PasswordHash, RoleId, IsActive, CreatedAt)
        VALUES (LTRIM(RTRIM(@FullName)), LOWER(LTRIM(RTRIM(@Email))), NULLIF(LTRIM(RTRIM(@Mobile)), ''), @PasswordHash, 2, 0, GETDATE());

        DECLARE @NewUserId INT = SCOPE_IDENTITY();

        -- Split FullName
        DECLARE @FirstName NVARCHAR(50);
        DECLARE @LastName NVARCHAR(50);
        DECLARE @SpaceIndex INT = CHARINDEX(' ', LTRIM(RTRIM(@FullName)));

        IF @SpaceIndex > 0
        BEGIN
            SET @FirstName = SUBSTRING(LTRIM(RTRIM(@FullName)), 1, @SpaceIndex - 1);
            SET @LastName = SUBSTRING(LTRIM(RTRIM(@FullName)), @SpaceIndex + 1, 50);
        END
        ELSE
        BEGIN
            SET @FirstName = LTRIM(RTRIM(@FullName));
            SET @LastName = '-';
        END

        -- Generate Employee Code
        DECLARE @EmployeeCode NVARCHAR(50) = 'TCH' + CAST(YEAR(GETDATE()) AS NVARCHAR(4)) + '-' + RIGHT('0000' + CAST(@NewUserId AS NVARCHAR(10)), 4);

        -- Combine qualification and specialization if both exist
        DECLARE @FullQualification NVARCHAR(200) = NULLIF(LTRIM(RTRIM(@Qualification)), '');
        IF @SubjectSpecialization IS NOT NULL AND LTRIM(RTRIM(@SubjectSpecialization)) <> ''
        BEGIN
            IF @FullQualification IS NOT NULL
                SET @FullQualification = @FullQualification + ' (' + LTRIM(RTRIM(@SubjectSpecialization)) + ')';
            ELSE
                SET @FullQualification = LTRIM(RTRIM(@SubjectSpecialization));
        END

        -- Insert into Teachers
        INSERT INTO Teachers (UserId, EmployeeCode, FirstName, LastName, Mobile, Email, Qualification, JoiningDate, IsActive, CreatedAt)
        VALUES (@NewUserId, @EmployeeCode, @FirstName, @LastName, NULLIF(LTRIM(RTRIM(@Mobile)), ''), LOWER(LTRIM(RTRIM(@Email))), @FullQualification, CAST(GETDATE() AS DATE), 0, GETDATE());

        COMMIT TRANSACTION;
        SELECT @NewUserId AS UserId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SELECT 0 AS UserId;
    END CATCH
END;
GO

-- 4.3 Get Pending Registrations
CREATE OR ALTER PROCEDURE sp_GetPendingRegistrations
AS
BEGIN
    SET NOCOUNT ON;
    SET QUOTED_IDENTIFIER ON;

    SELECT 
        u.UserId,
        u.FullName,
        u.Email,
        u.Mobile,
        r.RoleName,
        u.CreatedAt,
        CASE 
            WHEN r.RoleName = 'Student' THEN s.AdmissionNo
            WHEN r.RoleName = 'Teacher' THEN t.EmployeeCode
            ELSE NULL 
        END AS RegistrationCode,
        CASE 
            WHEN r.RoleName = 'Teacher' THEN t.Qualification
            ELSE NULL 
        END AS Qualification
    FROM Users u
    INNER JOIN Roles r ON u.RoleId = r.RoleId
    LEFT JOIN Students s ON u.UserId = s.UserId
    LEFT JOIN Teachers t ON u.UserId = t.UserId
    WHERE u.IsActive = 0
    ORDER BY u.CreatedAt DESC;
END;
GO

-- 4.3.1 Get Paged Pending Registrations (With Search, Role Filter, Sorting, Pagination, and Metric Stats)
CREATE OR ALTER PROCEDURE sp_GetPagedPendingRegistrations
    @SearchTerm NVARCHAR(100) = NULL,
    @Role NVARCHAR(50) = NULL,
    @PageNumber INT = 1,
    @PageSize INT = 10,
    @SortColumn NVARCHAR(50) = 'AppliedDate',
    @SortDirection NVARCHAR(10) = 'DESC',
    @TotalCount INT OUTPUT,
    @TotalPending INT OUTPUT,
    @StudentPending INT OUTPUT,
    @TeacherPending INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET QUOTED_IDENTIFIER ON;

    SET @SearchTerm = LTRIM(RTRIM(@SearchTerm));
    IF @SearchTerm = '' SET @SearchTerm = NULL;

    IF @Role IS NOT NULL
    BEGIN
        SET @Role = LTRIM(RTRIM(@Role));
        IF @Role = '' OR @Role = 'All' SET @Role = NULL;
    END

    IF @PageNumber IS NULL OR @PageNumber < 1 SET @PageNumber = 1;
    IF @PageSize IS NULL OR @PageSize < 1 SET @PageSize = 10;

    IF @SortColumn IS NULL OR @SortColumn = '' SET @SortColumn = 'AppliedDate';
    IF @SortDirection IS NULL OR @SortDirection = '' SET @SortDirection = 'DESC';
    SET @SortDirection = UPPER(@SortDirection);
    IF @SortDirection NOT IN ('ASC', 'DESC') SET @SortDirection = 'DESC';

    -- 1. Overall stats for metric cards (full pending counts)
    SELECT 
        @TotalPending = COUNT(1),
        @StudentPending = SUM(CASE WHEN r.RoleName = 'Student' THEN 1 ELSE 0 END),
        @TeacherPending = SUM(CASE WHEN r.RoleName = 'Teacher' THEN 1 ELSE 0 END)
    FROM Users u
    INNER JOIN Roles r ON u.RoleId = r.RoleId
    WHERE u.IsActive = 0;

    SET @TotalPending = ISNULL(@TotalPending, 0);
    SET @StudentPending = ISNULL(@StudentPending, 0);
    SET @TeacherPending = ISNULL(@TeacherPending, 0);

    -- 2. Filtered count matching search & role
    SELECT @TotalCount = COUNT(1)
    FROM Users u
    INNER JOIN Roles r ON u.RoleId = r.RoleId
    LEFT JOIN Students s ON u.UserId = s.UserId
    LEFT JOIN Teachers t ON u.UserId = t.UserId
    WHERE u.IsActive = 0
      AND (@Role IS NULL OR r.RoleName = @Role)
      AND (@SearchTerm IS NULL OR (
          u.FullName LIKE '%' + @SearchTerm + '%'
          OR u.Email LIKE '%' + @SearchTerm + '%'
          OR u.Mobile LIKE '%' + @SearchTerm + '%'
          OR s.AdmissionNo LIKE '%' + @SearchTerm + '%'
          OR t.EmployeeCode LIKE '%' + @SearchTerm + '%'
          OR t.Qualification LIKE '%' + @SearchTerm + '%'
      ));

    SET @TotalCount = ISNULL(@TotalCount, 0);

    -- 3. Paged & Sorted Result Set
    SELECT 
        u.UserId,
        u.FullName,
        u.Email,
        u.Mobile,
        u.RoleId,
        r.RoleName,
        u.IsActive,
        u.CreatedAt,
        CASE 
            WHEN r.RoleName = 'Teacher' THEN t.Qualification
            ELSE NULL 
        END AS ExtraInfo,
        CASE 
            WHEN r.RoleName = 'Student' THEN s.AdmissionNo
            WHEN r.RoleName = 'Teacher' THEN t.EmployeeCode
            ELSE NULL 
        END AS ReferenceCode
    FROM Users u
    INNER JOIN Roles r ON u.RoleId = r.RoleId
    LEFT JOIN Students s ON u.UserId = s.UserId
    LEFT JOIN Teachers t ON u.UserId = t.UserId
    WHERE u.IsActive = 0
      AND (@Role IS NULL OR r.RoleName = @Role)
      AND (@SearchTerm IS NULL OR (
          u.FullName LIKE '%' + @SearchTerm + '%'
          OR u.Email LIKE '%' + @SearchTerm + '%'
          OR u.Mobile LIKE '%' + @SearchTerm + '%'
          OR s.AdmissionNo LIKE '%' + @SearchTerm + '%'
          OR t.EmployeeCode LIKE '%' + @SearchTerm + '%'
          OR t.Qualification LIKE '%' + @SearchTerm + '%'
      ))
    ORDER BY
        CASE WHEN @SortColumn = 'name' AND @SortDirection = 'ASC' THEN u.FullName END ASC,
        CASE WHEN @SortColumn = 'name' AND @SortDirection = 'DESC' THEN u.FullName END DESC,
        CASE WHEN @SortColumn = 'role' AND @SortDirection = 'ASC' THEN r.RoleName END ASC,
        CASE WHEN @SortColumn = 'role' AND @SortDirection = 'DESC' THEN r.RoleName END DESC,
        CASE WHEN @SortColumn = 'email' AND @SortDirection = 'ASC' THEN u.Email END ASC,
        CASE WHEN @SortColumn = 'email' AND @SortDirection = 'DESC' THEN u.Email END DESC,
        CASE WHEN @SortColumn IN ('AppliedDate', 'CreatedAt') AND @SortDirection = 'ASC' THEN u.CreatedAt END ASC,
        CASE WHEN @SortColumn IN ('AppliedDate', 'CreatedAt') AND @SortDirection = 'DESC' THEN u.CreatedAt END DESC,
        u.CreatedAt DESC
    OFFSET (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END;
GO

-- 4.4 Approve User
CREATE OR ALTER PROCEDURE sp_ApproveUser
    @UserId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET QUOTED_IDENTIFIER ON;

    UPDATE Users 
    SET IsActive = 1, UpdatedAt = GETDATE() 
    WHERE UserId = @UserId;

    -- Also activate linked Student or Teacher record
    UPDATE Students 
    SET IsActive = 1 
    WHERE UserId = @UserId;

    UPDATE Teachers 
    SET IsActive = 1 
    WHERE UserId = @UserId;

    SELECT @@ROWCOUNT;
END;
GO

-- 4.5 Reject User
CREATE OR ALTER PROCEDURE sp_RejectUser
    @UserId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET QUOTED_IDENTIFIER ON;

    DELETE FROM Students WHERE UserId = @UserId;
    DELETE FROM Teachers WHERE UserId = @UserId;
    DELETE FROM Users WHERE UserId = @UserId AND IsActive = 0;

    SELECT @@ROWCOUNT;
END;
GO


-- ====================================================================================================
-- 5. COURSE & SUBJECT STORED PROCEDURES
-- ====================================================================================================
PRINT '>>> 5. Deploying Course & Subject Management Procedures...';
GO

-- 5.1 Get All Courses (with optional IsActive filter and counts)
CREATE OR ALTER PROCEDURE sp_GetAllCourses
    @IsActive BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET QUOTED_IDENTIFIER ON;

    SELECT 
        c.CourseId,
        c.CourseName,
        c.Description,
        c.Duration,
        c.IsActive,
        c.CreatedAt,
        (SELECT COUNT(1) FROM CourseSubjects cs WHERE cs.CourseId = c.CourseId) AS SubjectsCount,
        (SELECT COUNT(1) FROM Batches b WHERE b.CourseId = c.CourseId AND b.Status = 'Active') AS BatchesCount
    FROM Courses c
    WHERE (@IsActive IS NULL OR c.IsActive = @IsActive)
    ORDER BY c.CourseName ASC;
END;
GO

-- 5.2 Get Active Courses Only (For Batch assignment / dropdowns)
CREATE OR ALTER PROCEDURE sp_GetActiveCourses
AS
BEGIN
    SET NOCOUNT ON;
    SET QUOTED_IDENTIFIER ON;

    SELECT 
        c.CourseId,
        c.CourseName,
        c.Description,
        c.Duration,
        c.IsActive,
        c.CreatedAt,
        (SELECT COUNT(1) FROM CourseSubjects cs WHERE cs.CourseId = c.CourseId) AS SubjectsCount,
        (SELECT COUNT(1) FROM Batches b WHERE b.CourseId = c.CourseId AND b.Status = 'Active') AS BatchesCount
    FROM Courses c
    WHERE c.IsActive = 1
    ORDER BY c.CourseName ASC;
END;
GO

-- 5.3 Delete Course (Strict Referencing Checks: Batches & Fee Structures)
CREATE OR ALTER PROCEDURE sp_DeleteCourse
    @CourseId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET QUOTED_IDENTIFIER ON;

    -- 1. Check if course is assigned to ANY batch (Batches table)
    IF EXISTS (SELECT 1 FROM Batches WHERE CourseId = @CourseId)
    BEGIN
        SELECT -2 AS Result; -- Cannot delete: assigned to batches
        RETURN;
    END

    -- 2. Check if course is linked to fee structures
    IF EXISTS (SELECT 1 FROM FeeStructures WHERE CourseId = @CourseId)
    BEGIN
        SELECT -3 AS Result; -- Cannot delete: fee structures configured
        RETURN;
    END

    -- Safe to delete: remove course-subject mappings, then course itself
    BEGIN TRANSACTION;
    BEGIN TRY
        DELETE FROM CourseSubjects WHERE CourseId = @CourseId;
        DELETE FROM Courses WHERE CourseId = @CourseId;
        COMMIT TRANSACTION;
        SELECT 1 AS Result; -- Hard deleted successfully
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SELECT 0 AS Result; -- Error
    END CATCH
END;
GO

-- 5.4 Delete Subject (Strict Referencing Checks: Courses, Batches, Sessions/Exams)
CREATE OR ALTER PROCEDURE sp_DeleteSubject
    @SubjectId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET QUOTED_IDENTIFIER ON;

    -- 1. Check if subject is assigned to ANY Course (CourseSubjects table)
    IF EXISTS (SELECT 1 FROM CourseSubjects WHERE SubjectId = @SubjectId)
    BEGIN
        SELECT -2 AS Result; -- Cannot delete: assigned to one or more courses
        RETURN;
    END

    -- 2. Check if subject is assigned to ANY Batch (BatchSubjects table)
    IF EXISTS (SELECT 1 FROM BatchSubjects WHERE SubjectId = @SubjectId)
    BEGIN
        SELECT -3 AS Result; -- Cannot delete: assigned to active batches
        RETURN;
    END

    -- 3. Check if subject has lectures or exam records
    IF EXISTS (SELECT 1 FROM ClassSessions WHERE SubjectId = @SubjectId) OR
       EXISTS (SELECT 1 FROM ExamSubjects WHERE SubjectId = @SubjectId) OR
       EXISTS (SELECT 1 FROM Results WHERE SubjectId = @SubjectId)
    BEGIN
        SELECT -4 AS Result; -- Cannot delete: historical academic records exist
        RETURN;
    END

    -- Safe to delete
    BEGIN TRANSACTION;
    BEGIN TRY
        DELETE FROM Subjects WHERE SubjectId = @SubjectId;
        COMMIT TRANSACTION;
        SELECT 1 AS Result; -- Hard deleted successfully
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SELECT 0 AS Result; -- Error
    END CATCH
END;
GO


-- ====================================================================================================
-- 6. BATCH MANAGEMENT STORED PROCEDURES
-- ====================================================================================================
PRINT '>>> 6. Deploying Batch Management Procedures...';
GO

-- 6.1 Delete Batch (Strict Multi-level Referencing Checks)
CREATE OR ALTER PROCEDURE sp_DeleteBatch
    @BatchId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET QUOTED_IDENTIFIER ON;

    -- 1. Check if batch has any students enrolled
    IF EXISTS (SELECT 1 FROM Enrollments WHERE BatchId = @BatchId)
    BEGIN
        SELECT -2 AS Result; -- Cannot delete: students enrolled
        RETURN;
    END

    -- 2. Check if batch has class sessions (which also ties to attendance)
    IF EXISTS (SELECT 1 FROM ClassSessions WHERE BatchId = @BatchId)
    BEGIN
        SELECT -3 AS Result; -- Cannot delete: class sessions or attendance records exist
        RETURN;
    END

    -- 3. Check if batch has exams
    IF EXISTS (SELECT 1 FROM Exams WHERE BatchId = @BatchId)
    BEGIN
        SELECT -4 AS Result; -- Cannot delete: exams scheduled/conducted
        RETURN;
    END

    -- 4. Check if batch has study materials
    IF EXISTS (SELECT 1 FROM StudyMaterials WHERE BatchId = @BatchId)
    BEGIN
        SELECT -5 AS Result; -- Cannot delete: study materials uploaded
        RETURN;
    END

    -- Safe to delete: remove batch subjects mapping first, then batch
    BEGIN TRANSACTION;
    BEGIN TRY
        DELETE FROM BatchSubjects WHERE BatchId = @BatchId;
        DELETE FROM Batches WHERE BatchId = @BatchId;
        COMMIT TRANSACTION;
        SELECT 1 AS Result;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SELECT 0 AS Result;
    END CATCH
END;
GO


-- ====================================================================================================
-- 7. STUDENT MANAGEMENT STORED PROCEDURES
-- ====================================================================================================
PRINT '>>> 7. Deploying Student Management Procedures...';
GO

-- 7.1 Auto-Generated Next Admission Number
CREATE OR ALTER PROCEDURE sp_GetNextAdmissionNumber
    @Prefix NVARCHAR(10) = 'ADM',
    @NextAdmissionNo NVARCHAR(50) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET QUOTED_IDENTIFIER ON;
    DECLARE @Year NVARCHAR(4) = CAST(YEAR(GETDATE()) AS NVARCHAR(4));
    DECLARE @Pattern NVARCHAR(20) = @Prefix + '-' + @Year + '-%';
    DECLARE @PrefixLen INT = LEN(@Prefix) + 1 + 4 + 1; -- e.g. LEN('ADM-2026-') = 9
    DECLARE @LastNumber INT = 0;

    SELECT @LastNumber = ISNULL(MAX(
        TRY_CAST(SUBSTRING(AdmissionNo, @PrefixLen + 1, 10) AS INT)
    ), 0)
    FROM Students
    WHERE AdmissionNo LIKE @Pattern;

    SET @NextAdmissionNo = @Prefix + '-' + @Year + '-' + RIGHT('0000' + CAST(@LastNumber + 1 AS NVARCHAR(10)), 4);
END;
GO

-- 7.2 Get Batches by Course Id (For Dynamic AJAX Dropdowns)
CREATE OR ALTER PROCEDURE sp_GetBatchesByCourse
    @CourseId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET QUOTED_IDENTIFIER ON;
    SELECT 
        b.BatchId,
        b.BatchName,
        b.Capacity,
        b.Status,
        b.StartTime,
        b.EndTime,
        b.RoomNo,
        (SELECT COUNT(1) FROM Enrollments e WHERE e.BatchId = b.BatchId AND e.Status = 'Active') AS EnrolledCount
    FROM Batches b
    WHERE b.CourseId = @CourseId AND b.Status = 'Active'
    ORDER BY b.BatchName ASC;
END;
GO

-- 7.3 Get Student Stats
CREATE OR ALTER PROCEDURE sp_GetStudentStats
AS
BEGIN
    SET NOCOUNT ON;
    SET QUOTED_IDENTIFIER ON;
    DECLARE @CurMonth INT = MONTH(GETDATE());
    DECLARE @CurYear  INT = YEAR(GETDATE());

    SELECT
        COUNT(1) AS TotalStudents,
        SUM(CASE WHEN IsActive = 1 THEN 1 ELSE 0 END) AS ActiveStudents,
        SUM(CASE WHEN IsActive = 0 THEN 1 ELSE 0 END) AS InactiveStudents,
        (SELECT COUNT(DISTINCT StudentId) FROM Enrollments WHERE Status = 'Active') AS EnrolledStudents,
        SUM(CASE WHEN MONTH(AdmissionDate) = @CurMonth AND YEAR(AdmissionDate) = @CurYear THEN 1 ELSE 0 END) AS NewAdmissionsThisMonth
    FROM Students;
END;
GO

-- 7.4 Get Paged Students (Search, Multi-Filter, Sort, Pagination)
CREATE OR ALTER PROCEDURE sp_GetPagedStudents
    @SearchTerm     NVARCHAR(100) = NULL,
    @PageNumber     INT           = 1,
    @PageSize       INT           = 6,
    @SortColumn     NVARCHAR(50)  = 'StudentId',
    @SortDirection  NVARCHAR(10)  = 'DESC',
    @CourseId       INT           = NULL,
    @BatchId        INT           = NULL,
    @StatusFilter   NVARCHAR(20)  = NULL, -- 'Active', 'Inactive'
    @TotalCount     INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET QUOTED_IDENTIFIER ON;

    SET @SearchTerm = LTRIM(RTRIM(@SearchTerm));
    IF @SearchTerm = '' SET @SearchTerm = NULL;

    IF @PageNumber < 1 SET @PageNumber = 1;
    IF @PageSize < 1   SET @PageSize = 6;

    IF @SortColumn IS NULL OR @SortColumn = '' SET @SortColumn = 'StudentId';
    IF @SortDirection IS NULL OR @SortDirection = '' SET @SortDirection = 'DESC';
    SET @SortDirection = UPPER(@SortDirection);
    IF @SortDirection NOT IN ('ASC', 'DESC') SET @SortDirection = 'DESC';

    -- CTE with Student + Latest Active Enrollment info
    ;WITH StudentData AS (
        SELECT 
            s.StudentId,
            s.UserId,
            s.AdmissionNo,
            s.FirstName,
            s.LastName,
            s.FirstName + ' ' + s.LastName AS FullName,
            s.Gender,
            s.DateOfBirth,
            s.Mobile,
            s.Email,
            s.Address,
            s.ParentName,
            s.ParentMobile,
            s.AdmissionDate,
            s.ProfileImage,
            s.IsActive,
            s.CreatedAt,
            e.EnrollmentId,
            e.BatchId,
            b.BatchName,
            b.CourseId,
            c.CourseName,
            e.Status AS EnrollmentStatus,
            ROW_NUMBER() OVER (
                PARTITION BY s.StudentId 
                ORDER BY CASE WHEN e.Status = 'Active' THEN 0 ELSE 1 END, e.EnrollmentId DESC
            ) AS rn
        FROM Students s
        LEFT JOIN Enrollments e ON s.StudentId = e.StudentId
        LEFT JOIN Batches b     ON e.BatchId = b.BatchId
        LEFT JOIN Courses c     ON b.CourseId = c.CourseId
    ),
    FilteredStudents AS (
        SELECT *
        FROM StudentData
        WHERE rn = 1
          AND (@SearchTerm IS NULL OR
               AdmissionNo LIKE '%' + @SearchTerm + '%' OR
               FirstName   LIKE '%' + @SearchTerm + '%' OR
               LastName    LIKE '%' + @SearchTerm + '%' OR
               FullName    LIKE '%' + @SearchTerm + '%' OR
               Mobile      LIKE '%' + @SearchTerm + '%' OR
               ParentName  LIKE '%' + @SearchTerm + '%' OR
               ParentMobile LIKE '%' + @SearchTerm + '%')
          AND (@CourseId IS NULL OR CourseId = @CourseId)
          AND (@BatchId  IS NULL OR BatchId  = @BatchId)
          AND (
               @StatusFilter IS NULL OR
               (@StatusFilter = 'Active'   AND IsActive = 1) OR
               (@StatusFilter = 'Inactive' AND IsActive = 0)
          )
    )
    SELECT @TotalCount = COUNT(1) FROM FilteredStudents;

    ;WITH FilteredStudents AS (
        SELECT 
            s.StudentId,
            s.UserId,
            s.AdmissionNo,
            s.FirstName,
            s.LastName,
            s.FirstName + ' ' + s.LastName AS FullName,
            s.Gender,
            s.DateOfBirth,
            s.Mobile,
            s.Email,
            s.Address,
            s.ParentName,
            s.ParentMobile,
            s.AdmissionDate,
            s.ProfileImage,
            s.IsActive,
            s.CreatedAt,
            e.EnrollmentId,
            e.BatchId,
            b.BatchName,
            b.CourseId,
            c.CourseName,
            e.Status AS EnrollmentStatus,
            ROW_NUMBER() OVER (
                PARTITION BY s.StudentId 
                ORDER BY CASE WHEN e.Status = 'Active' THEN 0 ELSE 1 END, e.EnrollmentId DESC
            ) AS rn
        FROM Students s
        LEFT JOIN Enrollments e ON s.StudentId = e.StudentId
        LEFT JOIN Batches b     ON e.BatchId = b.BatchId
        LEFT JOIN Courses c     ON b.CourseId = c.CourseId
    )
    SELECT 
        StudentId, UserId, AdmissionNo, FirstName, LastName, FullName,
        Gender, DateOfBirth, Mobile, Email, Address, ParentName, ParentMobile,
        AdmissionDate, ProfileImage, IsActive, CreatedAt,
        EnrollmentId, BatchId, BatchName, CourseId, CourseName, EnrollmentStatus
    FROM FilteredStudents
    WHERE rn = 1
      AND (@SearchTerm IS NULL OR
           AdmissionNo LIKE '%' + @SearchTerm + '%' OR
           FirstName   LIKE '%' + @SearchTerm + '%' OR
           LastName    LIKE '%' + @SearchTerm + '%' OR
           FullName    LIKE '%' + @SearchTerm + '%' OR
           Mobile      LIKE '%' + @SearchTerm + '%' OR
           ParentName  LIKE '%' + @SearchTerm + '%' OR
           ParentMobile LIKE '%' + @SearchTerm + '%')
      AND (@CourseId IS NULL OR CourseId = @CourseId)
      AND (@BatchId  IS NULL OR BatchId  = @BatchId)
      AND (
           @StatusFilter IS NULL OR
           (@StatusFilter = 'Active'   AND IsActive = 1) OR
           (@StatusFilter = 'Inactive' AND IsActive = 0)
      )
    ORDER BY
        CASE WHEN @SortColumn = 'FirstName'     AND @SortDirection = 'ASC'  THEN FirstName END ASC,
        CASE WHEN @SortColumn = 'FirstName'     AND @SortDirection = 'DESC' THEN FirstName END DESC,
        CASE WHEN @SortColumn = 'AdmissionNo'   AND @SortDirection = 'ASC'  THEN AdmissionNo END ASC,
        CASE WHEN @SortColumn = 'AdmissionNo'   AND @SortDirection = 'DESC' THEN AdmissionNo END DESC,
        CASE WHEN @SortColumn = 'AdmissionDate' AND @SortDirection = 'ASC'  THEN AdmissionDate END ASC,
        CASE WHEN @SortColumn = 'AdmissionDate' AND @SortDirection = 'DESC' THEN AdmissionDate END DESC,
        CASE WHEN @SortColumn = 'CourseName'    AND @SortDirection = 'ASC'  THEN CourseName END ASC,
        CASE WHEN @SortColumn = 'CourseName'    AND @SortDirection = 'DESC' THEN CourseName END DESC,
        CASE WHEN @SortColumn = 'BatchName'     AND @SortDirection = 'ASC'  THEN BatchName END ASC,
        CASE WHEN @SortColumn = 'BatchName'     AND @SortDirection = 'DESC' THEN BatchName END DESC,
        CASE WHEN @SortColumn = 'StudentId'     AND @SortDirection = 'ASC'  THEN StudentId END ASC,
        CASE WHEN @SortColumn = 'StudentId'     AND @SortDirection = 'DESC' THEN StudentId END DESC,
        StudentId DESC
    OFFSET (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END;
GO

-- 7.5 Get Student By Id (Full Details & Current Enrollment)
CREATE OR ALTER PROCEDURE sp_GetStudentById
    @StudentId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET QUOTED_IDENTIFIER ON;
    SELECT 
        s.StudentId,
        s.UserId,
        s.AdmissionNo,
        s.FirstName,
        s.LastName,
        s.FirstName + ' ' + s.LastName AS FullName,
        s.Gender,
        s.DateOfBirth,
        s.Mobile,
        s.Email,
        s.Address,
        s.ParentName,
        s.ParentMobile,
        s.AdmissionDate,
        s.ProfileImage,
        s.IsActive,
        s.CreatedAt,
        e.EnrollmentId,
        e.BatchId,
        b.BatchName,
        b.CourseId,
        c.CourseName,
        e.EnrollmentDate,
        e.Status AS EnrollmentStatus
    FROM Students s
    LEFT JOIN Enrollments e ON s.StudentId = e.StudentId AND e.Status = 'Active'
    LEFT JOIN Batches b     ON e.BatchId = b.BatchId
    LEFT JOIN Courses c     ON b.CourseId = c.CourseId
    WHERE s.StudentId = @StudentId;
END;
GO

-- 7.6 Get Student By User Id (For Student Portal & My Profile)
CREATE OR ALTER PROCEDURE sp_GetStudentByUserId
    @UserId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET QUOTED_IDENTIFIER ON;

    -- 1. If no direct link by UserId, try auto-link by Email or auto-create profile
    IF NOT EXISTS (SELECT 1 FROM Students WHERE UserId = @UserId)
    BEGIN
        DECLARE @UserEmail NVARCHAR(100);
        DECLARE @UserFullName NVARCHAR(100);
        DECLARE @UserMobile NVARCHAR(20);

        SELECT @UserEmail = LOWER(LTRIM(RTRIM(Email))),
               @UserFullName = FullName,
               @UserMobile = Mobile
        FROM Users WHERE UserId = @UserId;

        -- A. Auto-link if student exists with matching email and UserId IS NULL
        IF @UserEmail IS NOT NULL AND EXISTS (SELECT 1 FROM Students WHERE LOWER(Email) = @UserEmail AND UserId IS NULL)
        BEGIN
            UPDATE TOP (1) Students
            SET UserId = @UserId
            WHERE LOWER(Email) = @UserEmail AND UserId IS NULL;
        END
        -- B. If User has Student role (RoleId = 3) and no Student record exists, auto-create one
        ELSE IF NOT EXISTS (SELECT 1 FROM Students WHERE UserId = @UserId)
        BEGIN
            IF EXISTS (SELECT 1 FROM Users WHERE UserId = @UserId AND RoleId = 3)
            BEGIN
                DECLARE @NextAdmNo NVARCHAR(50);
                EXEC sp_GetNextAdmissionNumber 'ADM', @NextAdmNo OUTPUT;

                DECLARE @FName NVARCHAR(50) = @UserFullName;
                DECLARE @LName NVARCHAR(50) = '';
                DECLARE @SpaceIdx INT = CHARINDEX(' ', @UserFullName);
                IF @SpaceIdx > 0
                BEGIN
                    SET @FName = SUBSTRING(@UserFullName, 1, @SpaceIdx - 1);
                    SET @LName = SUBSTRING(@UserFullName, @SpaceIdx + 1, LEN(@UserFullName));
                END

                INSERT INTO Students (
                    UserId, AdmissionNo, FirstName, LastName,
                    Mobile, Email, AdmissionDate, IsActive, CreatedAt
                )
                VALUES (
                    @UserId, @NextAdmNo, @FName, @LName,
                    @UserMobile, @UserEmail, CAST(GETDATE() AS DATE), 1, SYSDATETIME()
                );
            END
        END
    END

    -- 2. Return student profile with active enrollment info
    SELECT 
        s.StudentId,
        s.UserId,
        s.AdmissionNo,
        s.FirstName,
        s.LastName,
        s.FirstName + ' ' + s.LastName AS FullName,
        s.Gender,
        s.DateOfBirth,
        s.Mobile,
        s.Email,
        s.Address,
        s.ParentName,
        s.ParentMobile,
        s.AdmissionDate,
        s.ProfileImage,
        s.IsActive,
        s.CreatedAt,
        e.EnrollmentId,
        e.BatchId,
        b.BatchName,
        b.CourseId,
        c.CourseName,
        e.EnrollmentDate,
        e.Status AS EnrollmentStatus
    FROM Students s
    LEFT JOIN Enrollments e ON s.StudentId = e.StudentId AND e.Status = 'Active'
    LEFT JOIN Batches b     ON e.BatchId = b.BatchId
    LEFT JOIN Courses c     ON b.CourseId = c.CourseId
    WHERE s.UserId = @UserId;
END;
GO

-- 7.7 Update Student Self-Profile (DOB, Gender, Address, Photo)
CREATE OR ALTER PROCEDURE sp_UpdateStudentProfile
    @StudentId      INT,
    @Gender         NVARCHAR(20)  = NULL,
    @DateOfBirth    DATE          = NULL,
    @Address        NVARCHAR(255) = NULL,
    @ProfileImage   NVARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET QUOTED_IDENTIFIER ON;

    UPDATE Students SET
        Gender       = ISNULL(@Gender, Gender),
        DateOfBirth  = ISNULL(@DateOfBirth, DateOfBirth),
        Address      = ISNULL(@Address, Address),
        ProfileImage = ISNULL(@ProfileImage, ProfileImage)
    WHERE StudentId = @StudentId;

    SELECT 1 AS Result;
END;
GO

-- 7.8 Create Student Admission (Transactional Student + Enrollment)
CREATE OR ALTER PROCEDURE sp_CreateStudentAdmission
    @AdmissionNo    NVARCHAR(50)  = NULL,
    @FirstName      NVARCHAR(50),
    @LastName       NVARCHAR(50),
    @Gender         NVARCHAR(20)  = NULL,
    @DateOfBirth    DATE          = NULL,
    @Mobile         NVARCHAR(20)  = NULL,
    @Email          NVARCHAR(100) = NULL,
    @Address        NVARCHAR(255) = NULL,
    @ParentName     NVARCHAR(100) = NULL,
    @ParentMobile   NVARCHAR(20)  = NULL,
    @AdmissionDate  DATE          = NULL,
    @ProfileImage   NVARCHAR(255) = NULL,
    @BatchId        INT           = NULL,
    @EnrollmentDate DATE          = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET QUOTED_IDENTIFIER ON;
    BEGIN TRANSACTION;

    BEGIN TRY
        -- Auto-generate AdmissionNo if not supplied
        IF @AdmissionNo IS NULL OR LTRIM(RTRIM(@AdmissionNo)) = ''
        BEGIN
            EXEC sp_GetNextAdmissionNumber 'ADM', @AdmissionNo OUTPUT;
        END

        -- Check duplicate AdmissionNo
        IF EXISTS (SELECT 1 FROM Students WHERE AdmissionNo = @AdmissionNo)
        BEGIN
            ROLLBACK TRANSACTION;
            SELECT -1 AS StudentId; -- Duplicate Admission Number
            RETURN;
        END

        IF @AdmissionDate IS NULL
            SET @AdmissionDate = CAST(GETDATE() AS DATE);

        IF @EnrollmentDate IS NULL
            SET @EnrollmentDate = @AdmissionDate;

        -- Insert Student (UserId is NULL for walk-in admissions without login account)
        INSERT INTO Students (
            UserId, AdmissionNo, FirstName, LastName, Gender, DateOfBirth,
            Mobile, Email, Address, ParentName, ParentMobile,
            AdmissionDate, ProfileImage, IsActive, CreatedAt
        )
        VALUES (
            NULL, @AdmissionNo, @FirstName, @LastName, @Gender, @DateOfBirth,
            @Mobile, @Email, @Address, @ParentName, @ParentMobile,
            @AdmissionDate, @ProfileImage, 1, SYSDATETIME()
        );

        DECLARE @NewStudentId INT = SCOPE_IDENTITY();

        -- Enroll into Batch if BatchId provided and batch exists
        IF @BatchId IS NOT NULL AND @BatchId > 0 AND EXISTS (SELECT 1 FROM Batches WHERE BatchId = @BatchId)
        BEGIN
            INSERT INTO Enrollments (StudentId, BatchId, EnrollmentDate, Status)
            VALUES (@NewStudentId, @BatchId, @EnrollmentDate, 'Active');
        END

        COMMIT TRANSACTION;
        SELECT @NewStudentId AS StudentId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SELECT 0 AS StudentId;
    END CATCH
END;
GO

-- 7.9 Update Student Details & Batch Enrollment
CREATE OR ALTER PROCEDURE sp_UpdateStudent
    @StudentId      INT,
    @AdmissionNo    NVARCHAR(50),
    @FirstName      NVARCHAR(50),
    @LastName       NVARCHAR(50),
    @Gender         NVARCHAR(20)  = NULL,
    @DateOfBirth    DATE          = NULL,
    @Mobile         NVARCHAR(20)  = NULL,
    @Email          NVARCHAR(100) = NULL,
    @Address        NVARCHAR(255) = NULL,
    @ParentName     NVARCHAR(100) = NULL,
    @ParentMobile   NVARCHAR(20)  = NULL,
    @AdmissionDate  DATE          = NULL,
    @ProfileImage   NVARCHAR(255) = NULL,
    @IsActive       BIT           = 1,
    @BatchId        INT           = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET QUOTED_IDENTIFIER ON;
    BEGIN TRANSACTION;

    BEGIN TRY
        -- Check duplicate AdmissionNo for other student
        IF EXISTS (SELECT 1 FROM Students WHERE AdmissionNo = @AdmissionNo AND StudentId <> @StudentId)
        BEGIN
            ROLLBACK TRANSACTION;
            SELECT -1; -- Duplicate
            RETURN;
        END

        -- Update Student Info
        UPDATE Students SET
            AdmissionNo  = @AdmissionNo,
            FirstName    = @FirstName,
            LastName     = @LastName,
            Gender       = @Gender,
            DateOfBirth  = @DateOfBirth,
            Mobile       = @Mobile,
            Email        = @Email,
            Address      = @Address,
            ParentName   = @ParentName,
            ParentMobile = @ParentMobile,
            AdmissionDate = ISNULL(@AdmissionDate, AdmissionDate),
            ProfileImage = ISNULL(@ProfileImage, ProfileImage),
            IsActive     = @IsActive
        WHERE StudentId = @StudentId;

        -- Handle Batch Enrollment
        IF @BatchId IS NOT NULL AND @BatchId > 0 AND EXISTS (SELECT 1 FROM Batches WHERE BatchId = @BatchId)
        BEGIN
            DECLARE @CurrentBatchId INT = NULL;
            SELECT TOP 1 @CurrentBatchId = BatchId 
            FROM Enrollments 
            WHERE StudentId = @StudentId AND Status = 'Active';

            IF @CurrentBatchId IS NULL
            BEGIN
                -- No active enrollment, insert new
                INSERT INTO Enrollments (StudentId, BatchId, EnrollmentDate, Status)
                VALUES (@StudentId, @BatchId, CAST(GETDATE() AS DATE), 'Active');
            END
            ELSE IF @CurrentBatchId <> @BatchId
            BEGIN
                -- Changed batch: mark previous as Transferred
                UPDATE Enrollments SET Status = 'Transferred'
                WHERE StudentId = @StudentId AND Status = 'Active';

                INSERT INTO Enrollments (StudentId, BatchId, EnrollmentDate, Status)
                VALUES (@StudentId, @BatchId, CAST(GETDATE() AS DATE), 'Active');
            END
        END

        COMMIT TRANSACTION;
        SELECT 1; -- Success
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        SELECT 0; -- Error
    END CATCH
END;
GO

-- 7.10 Delete Or Deactivate Student
CREATE OR ALTER PROCEDURE sp_DeleteOrDeactivateStudent
    @StudentId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET QUOTED_IDENTIFIER ON;

    -- Check if student has records in Attendance or StudentFees
    IF EXISTS (SELECT 1 FROM Attendance WHERE StudentId = @StudentId) OR
       EXISTS (SELECT 1 FROM StudentFees WHERE StudentId = @StudentId) OR
       EXISTS (SELECT 1 FROM Results WHERE StudentId = @StudentId)
    BEGIN
        -- Safe Soft Deactivate
        UPDATE Students SET IsActive = 0 WHERE StudentId = @StudentId;
        UPDATE Enrollments SET Status = 'Inactive' WHERE StudentId = @StudentId AND Status = 'Active';
        SELECT 2; -- Deactivated
        RETURN;
    END

    -- Safe Hard Delete if no financial or academic records
    BEGIN TRANSACTION;
    BEGIN TRY
        DELETE FROM StudentDocuments WHERE StudentId = @StudentId;
        DELETE FROM Enrollments WHERE StudentId = @StudentId;
        DELETE FROM Students WHERE StudentId = @StudentId;
        COMMIT TRANSACTION;
        SELECT 1; -- Deleted
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SELECT 0; -- Error
    END CATCH
END;
GO


-- ====================================================================================================
-- 8. TEACHER MANAGEMENT STORED PROCEDURES
-- ====================================================================================================
PRINT '>>> 8. Deploying Teacher Management Procedures...';
GO

-- 8.1 Auto-Generated Next Employee Code (e.g. TCH-2026-0001)
CREATE OR ALTER PROCEDURE sp_GetNextEmployeeCode
    @Prefix NVARCHAR(10) = 'TCH'
AS
BEGIN
    SET NOCOUNT ON;
    SET QUOTED_IDENTIFIER ON;

    DECLARE @CurrentYear NVARCHAR(4) = CAST(YEAR(GETDATE()) AS NVARCHAR(4));
    DECLARE @FullPrefix NVARCHAR(20) = @Prefix + '-' + @CurrentYear + '-';
    DECLARE @NextNumber INT = 1;

    -- Look for highest number with current year prefix
    SELECT @NextNumber = ISNULL(MAX(
        TRY_CAST(SUBSTRING(EmployeeCode, LEN(@FullPrefix) + 1, 10) AS INT)
    ), 0) + 1
    FROM Teachers
    WHERE EmployeeCode LIKE @FullPrefix + '%';

    SELECT @FullPrefix + RIGHT('0000' + CAST(@NextNumber AS NVARCHAR(10)), 4) AS NextEmployeeCode;
END;
GO

-- 8.2 Get Teacher Stats
CREATE OR ALTER PROCEDURE sp_GetTeacherStats
AS
BEGIN
    SET NOCOUNT ON;
    SET QUOTED_IDENTIFIER ON;

    SELECT
        COUNT(1) AS TotalTeachers,
        SUM(CASE WHEN IsActive = 1 THEN 1 ELSE 0 END) AS ActiveTeachers,
        SUM(CASE WHEN IsActive = 0 THEN 1 ELSE 0 END) AS InactiveTeachers,
        (SELECT COUNT(DISTINCT BatchId) FROM BatchSubjects WHERE TeacherId IS NOT NULL) AS AssignedBatchesCount
    FROM Teachers;
END;
GO

-- 8.3 Get Paged Teachers (Search, Filter, Sort, Pagination)
CREATE OR ALTER PROCEDURE sp_GetPagedTeachers
    @SearchTerm     NVARCHAR(100) = NULL,
    @PageNumber     INT           = 1,
    @PageSize       INT           = 10,
    @SortColumn     NVARCHAR(50)  = 'TeacherId',
    @SortDirection  NVARCHAR(10)  = 'DESC',
    @StatusFilter   NVARCHAR(20)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET QUOTED_IDENTIFIER ON;

    SET @SearchTerm = NULLIF(LTRIM(RTRIM(@SearchTerm)), '');

    -- Count total matching records
    SELECT COUNT(1) AS TotalCount
    FROM Teachers t
    WHERE (@SearchTerm IS NULL OR
           t.EmployeeCode LIKE '%' + @SearchTerm + '%' OR
           t.FirstName    LIKE '%' + @SearchTerm + '%' OR
           t.LastName     LIKE '%' + @SearchTerm + '%' OR
           (t.FirstName + ' ' + t.LastName) LIKE '%' + @SearchTerm + '%' OR
           t.Mobile       LIKE '%' + @SearchTerm + '%' OR
           t.Email        LIKE '%' + @SearchTerm + '%' OR
           t.Qualification LIKE '%' + @SearchTerm + '%')
      AND (
           @StatusFilter IS NULL OR
           (@StatusFilter = 'Active'   AND t.IsActive = 1) OR
           (@StatusFilter = 'Inactive' AND t.IsActive = 0)
      );

    -- Paged data
    SELECT 
        t.TeacherId,
        t.UserId,
        t.EmployeeCode,
        t.FirstName,
        t.LastName,
        (t.FirstName + ' ' + t.LastName) AS FullName,
        t.Mobile,
        t.Email,
        t.Qualification,
        t.JoiningDate,
        t.ProfileImage,
        t.IsActive,
        t.CreatedAt,
        (SELECT COUNT(DISTINCT bs.BatchId) FROM BatchSubjects bs WHERE bs.TeacherId = t.TeacherId) AS AssignedBatchesCount
    FROM Teachers t
    WHERE (@SearchTerm IS NULL OR
           t.EmployeeCode LIKE '%' + @SearchTerm + '%' OR
           t.FirstName    LIKE '%' + @SearchTerm + '%' OR
           t.LastName     LIKE '%' + @SearchTerm + '%' OR
           (t.FirstName + ' ' + t.LastName) LIKE '%' + @SearchTerm + '%' OR
           t.Mobile       LIKE '%' + @SearchTerm + '%' OR
           t.Email        LIKE '%' + @SearchTerm + '%' OR
           t.Qualification LIKE '%' + @SearchTerm + '%')
      AND (
           @StatusFilter IS NULL OR
           (@StatusFilter = 'Active'   AND t.IsActive = 1) OR
           (@StatusFilter = 'Inactive' AND t.IsActive = 0)
      )
    ORDER BY
        CASE WHEN @SortColumn = 'FirstName'    AND @SortDirection = 'ASC'  THEN t.FirstName END ASC,
        CASE WHEN @SortColumn = 'FirstName'    AND @SortDirection = 'DESC' THEN t.FirstName END DESC,
        CASE WHEN @SortColumn = 'EmployeeCode' AND @SortDirection = 'ASC'  THEN t.EmployeeCode END ASC,
        CASE WHEN @SortColumn = 'EmployeeCode' AND @SortDirection = 'DESC' THEN t.EmployeeCode END DESC,
        CASE WHEN @SortColumn = 'JoiningDate'  AND @SortDirection = 'ASC'  THEN t.JoiningDate END ASC,
        CASE WHEN @SortColumn = 'JoiningDate'  AND @SortDirection = 'DESC' THEN t.JoiningDate END DESC,
        CASE WHEN @SortColumn = 'TeacherId'    AND @SortDirection = 'ASC'  THEN t.TeacherId END ASC,
        CASE WHEN @SortColumn = 'TeacherId'    AND @SortDirection = 'DESC' THEN t.TeacherId END DESC,
        t.TeacherId DESC
    OFFSET (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END;
GO

-- 8.4 Get Teacher By Id
CREATE OR ALTER PROCEDURE sp_GetTeacherById
    @TeacherId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET QUOTED_IDENTIFIER ON;

    SELECT 
        t.TeacherId,
        t.UserId,
        t.EmployeeCode,
        t.FirstName,
        t.LastName,
        (t.FirstName + ' ' + t.LastName) AS FullName,
        t.Mobile,
        t.Email,
        t.Qualification,
        t.JoiningDate,
        t.ProfileImage,
        t.IsActive,
        t.CreatedAt,
        (SELECT COUNT(DISTINCT bs.BatchId) FROM BatchSubjects bs WHERE bs.TeacherId = t.TeacherId) AS AssignedBatchesCount
    FROM Teachers t
    WHERE t.TeacherId = @TeacherId;
END;
GO

-- 8.5 Get Teacher By User Id
CREATE OR ALTER PROCEDURE sp_GetTeacherByUserId
    @UserId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET QUOTED_IDENTIFIER ON;

    -- 1. If no direct link by UserId, try auto-link by Email or auto-create profile
    IF NOT EXISTS (SELECT 1 FROM Teachers WHERE UserId = @UserId)
    BEGIN
        DECLARE @UserEmail NVARCHAR(100);
        DECLARE @UserFullName NVARCHAR(100);
        DECLARE @UserMobile NVARCHAR(20);

        SELECT @UserEmail = LOWER(LTRIM(RTRIM(Email))),
               @UserFullName = FullName,
               @UserMobile = Mobile
        FROM Users WHERE UserId = @UserId;

        -- A. Auto-link if teacher exists with matching email and UserId IS NULL
        IF @UserEmail IS NOT NULL AND EXISTS (SELECT 1 FROM Teachers WHERE LOWER(Email) = @UserEmail AND UserId IS NULL)
        BEGIN
            UPDATE TOP (1) Teachers
            SET UserId = @UserId
            WHERE LOWER(Email) = @UserEmail AND UserId IS NULL;
        END
        -- B. If User has Teacher role (RoleId = 2) and no Teacher record exists, auto-create one
        ELSE IF NOT EXISTS (SELECT 1 FROM Teachers WHERE UserId = @UserId)
        BEGIN
            IF EXISTS (SELECT 1 FROM Users WHERE UserId = @UserId AND RoleId = 2)
            BEGIN
                DECLARE @NextEmpCode NVARCHAR(50);
                DECLARE @CurYear NVARCHAR(4) = CAST(YEAR(GETDATE()) AS NVARCHAR(4));
                DECLARE @FullPref NVARCHAR(20) = 'TCH-' + @CurYear + '-';
                DECLARE @NextNum INT = 1;

                SELECT @NextNum = ISNULL(MAX(
                    TRY_CAST(SUBSTRING(EmployeeCode, LEN(@FullPref) + 1, 10) AS INT)
                ), 0) + 1
                FROM Teachers
                WHERE EmployeeCode LIKE @FullPref + '%';

                SET @NextEmpCode = @FullPref + RIGHT('0000' + CAST(@NextNum AS NVARCHAR(10)), 4);

                DECLARE @TFName NVARCHAR(50) = @UserFullName;
                DECLARE @TLName NVARCHAR(50) = '';
                DECLARE @TSpaceIdx INT = CHARINDEX(' ', @UserFullName);
                IF @TSpaceIdx > 0
                BEGIN
                    SET @TFName = SUBSTRING(@UserFullName, 1, @TSpaceIdx - 1);
                    SET @TLName = SUBSTRING(@UserFullName, @TSpaceIdx + 1, LEN(@UserFullName));
                END

                INSERT INTO Teachers (
                    UserId, EmployeeCode, FirstName, LastName,
                    Mobile, Email, JoiningDate, IsActive, CreatedAt
                )
                VALUES (
                    @UserId, @NextEmpCode, @TFName, @TLName,
                    @UserMobile, @UserEmail, CAST(GETDATE() AS DATE), 1, GETDATE()
                );
            END
        END
    END

    -- 2. Return teacher profile with batch count
    SELECT 
        t.TeacherId,
        t.UserId,
        t.EmployeeCode,
        t.FirstName,
        t.LastName,
        (t.FirstName + ' ' + t.LastName) AS FullName,
        t.Mobile,
        t.Email,
        t.Qualification,
        t.JoiningDate,
        t.ProfileImage,
        t.IsActive,
        t.CreatedAt,
        (SELECT COUNT(DISTINCT bs.BatchId) FROM BatchSubjects bs WHERE bs.TeacherId = t.TeacherId) AS AssignedBatchesCount
    FROM Teachers t
    WHERE t.UserId = @UserId;
END;
GO

-- 8.6 Get Batches Assigned to Teacher
CREATE OR ALTER PROCEDURE sp_GetTeacherBatches
    @TeacherId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET QUOTED_IDENTIFIER ON;

    SELECT 
        bs.BatchSubjectId,
        b.BatchId,
        b.BatchName,
        c.CourseId,
        c.CourseName,
        s.SubjectId,
        s.SubjectName,
        b.RoomNo,
        b.StartTime,
        b.EndTime,
        b.Status AS BatchStatus,
        (SELECT COUNT(1) FROM Enrollments e WHERE e.BatchId = b.BatchId AND e.Status = 'Active') AS EnrolledStudentsCount
    FROM BatchSubjects bs
    INNER JOIN Batches b  ON bs.BatchId = b.BatchId
    INNER JOIN Courses c  ON b.CourseId = c.CourseId
    INNER JOIN Subjects s ON bs.SubjectId = s.SubjectId
    WHERE bs.TeacherId = @TeacherId
    ORDER BY b.Status ASC, b.BatchName ASC, s.SubjectName ASC;
END;
GO

-- 8.7 Create Teacher (Transactional: Users + Teachers)
CREATE OR ALTER PROCEDURE sp_CreateTeacher
    @EmployeeCode   NVARCHAR(50),
    @FirstName      NVARCHAR(50),
    @LastName       NVARCHAR(50),
    @Mobile         NVARCHAR(20)  = NULL,
    @Email          NVARCHAR(100),
    @Qualification  NVARCHAR(100) = NULL,
    @JoiningDate    DATE          = NULL,
    @ProfileImage   NVARCHAR(255) = NULL,
    @PasswordHash   NVARCHAR(255),
    @IsActive       BIT           = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET QUOTED_IDENTIFIER ON;

    SET @Email = LOWER(LTRIM(RTRIM(@Email)));

    -- Duplicate check on Email
    IF EXISTS (SELECT 1 FROM Users WHERE LOWER(Email) = @Email)
    BEGIN
        SELECT -1 AS TeacherId; -- Email already exists
        RETURN;
    END

    -- Duplicate check on EmployeeCode
    IF EXISTS (SELECT 1 FROM Teachers WHERE LOWER(LTRIM(RTRIM(EmployeeCode))) = LOWER(LTRIM(RTRIM(@EmployeeCode))))
    BEGIN
        SELECT -2 AS TeacherId; -- EmployeeCode already exists
        RETURN;
    END

    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @UserId INT;
        DECLARE @FullName NVARCHAR(100) = LTRIM(RTRIM(@FirstName)) + ' ' + LTRIM(RTRIM(@LastName));

        -- 1. Insert into Users with Role 2 (Teacher)
        INSERT INTO Users (FullName, Email, Mobile, PasswordHash, RoleId, IsActive, CreatedAt)
        VALUES (@FullName, @Email, @Mobile, @PasswordHash, 2, @IsActive, GETDATE());

        SET @UserId = SCOPE_IDENTITY();

        -- 2. Create Teacher profile
        INSERT INTO Teachers (
            UserId, EmployeeCode, FirstName, LastName, Mobile, Email,
            Qualification, JoiningDate, ProfileImage, IsActive, CreatedAt
        )
        VALUES (
            @UserId, @EmployeeCode, LTRIM(RTRIM(@FirstName)), LTRIM(RTRIM(@LastName)),
            @Mobile, @Email, @Qualification, ISNULL(@JoiningDate, CAST(GETDATE() AS DATE)),
            @ProfileImage, @IsActive, GETDATE()
        );

        DECLARE @TeacherId INT = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
        SELECT @TeacherId AS TeacherId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SELECT 0 AS TeacherId; -- Error
    END CATCH
END;
GO

-- 8.8 Update Teacher
CREATE OR ALTER PROCEDURE sp_UpdateTeacher
    @TeacherId      INT,
    @FirstName      NVARCHAR(50),
    @LastName       NVARCHAR(50),
    @Mobile         NVARCHAR(20)  = NULL,
    @Email          NVARCHAR(100),
    @Qualification  NVARCHAR(100) = NULL,
    @JoiningDate    DATE          = NULL,
    @ProfileImage   NVARCHAR(255) = NULL,
    @IsActive       BIT           = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET QUOTED_IDENTIFIER ON;

    SET @Email = LOWER(LTRIM(RTRIM(@Email)));

    -- Fetch current UserId
    DECLARE @UserId INT;
    SELECT @UserId = UserId FROM Teachers WHERE TeacherId = @TeacherId;

    IF @UserId IS NULL
    BEGIN
        SELECT 0 AS Result; -- Not found
        RETURN;
    END

    -- Check if another user has this email
    IF EXISTS (SELECT 1 FROM Users WHERE LOWER(Email) = @Email AND UserId <> @UserId)
    BEGIN
        SELECT -1 AS Result; -- Email conflict
        RETURN;
    END

    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @FullName NVARCHAR(100) = LTRIM(RTRIM(@FirstName)) + ' ' + LTRIM(RTRIM(@LastName));

        -- 1. Update Users table
        UPDATE Users
        SET FullName  = @FullName,
            Email     = @Email,
            Mobile    = @Mobile,
            IsActive  = @IsActive,
            UpdatedAt = GETDATE()
        WHERE UserId  = @UserId;

        -- 2. Update Teachers table
        UPDATE Teachers
        SET FirstName    = LTRIM(RTRIM(@FirstName)),
            LastName     = LTRIM(RTRIM(@LastName)),
            Mobile       = @Mobile,
            Email        = @Email,
            Qualification = @Qualification,
            JoiningDate  = ISNULL(@JoiningDate, JoiningDate),
            ProfileImage = ISNULL(@ProfileImage, ProfileImage),
            IsActive     = @IsActive
        WHERE TeacherId  = @TeacherId;

        COMMIT TRANSACTION;
        SELECT 1 AS Result;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SELECT 0 AS Result;
    END CATCH
END;
GO

-- 8.9 Delete Teacher (with strict FK Dependency checks)
CREATE OR ALTER PROCEDURE sp_DeleteTeacher
    @TeacherId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET QUOTED_IDENTIFIER ON;

    -- 1. Check if assigned to any batch subjects
    IF EXISTS (SELECT 1 FROM BatchSubjects WHERE TeacherId = @TeacherId)
    BEGIN
        SELECT -2 AS Result; -- Cannot delete: assigned to batches
        RETURN;
    END

    -- 2. Check if linked to class sessions
    IF EXISTS (SELECT 1 FROM ClassSessions WHERE TeacherId = @TeacherId)
    BEGIN
        SELECT -3 AS Result; -- Cannot delete: class sessions exist
        RETURN;
    END

    -- 3. Check if study materials uploaded
    IF EXISTS (SELECT 1 FROM StudyMaterials WHERE UploadedBy = @TeacherId)
    BEGIN
        SELECT -4 AS Result; -- Cannot delete: study materials exist
        RETURN;
    END

    DECLARE @UserId INT;
    SELECT @UserId = UserId FROM Teachers WHERE TeacherId = @TeacherId;

    BEGIN TRANSACTION;
    BEGIN TRY
        DELETE FROM Teachers WHERE TeacherId = @TeacherId;
        IF @UserId IS NOT NULL
        BEGIN
            DELETE FROM Users WHERE UserId = @UserId;
        END

        COMMIT TRANSACTION;
        SELECT 1 AS Result;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SELECT 0 AS Result;
    END CATCH
END;
GO

-- 8.10 Get All Active Teachers (for Dropdowns)
CREATE OR ALTER PROCEDURE sp_GetAllActiveTeachers
AS
BEGIN
    SET NOCOUNT ON;
    SET QUOTED_IDENTIFIER ON;

    SELECT 
        TeacherId,
        UserId,
        EmployeeCode,
        FirstName,
        LastName,
        (FirstName + ' ' + LastName) AS FullName,
        Qualification,
        Mobile,
        Email,
        ProfileImage,
        IsActive
    FROM Teachers
    WHERE IsActive = 1
    ORDER BY FirstName ASC, LastName ASC;
END;
GO


-- ====================================================================================================
-- 9. POST-MIGRATION VERIFICATION & DIAGNOSTICS
-- ====================================================================================================
PRINT '>>> 9. Performing Diagnostics Verification...';
GO

SELECT 'Permissions' AS [Object], COUNT(1) AS [Count] FROM Permissions
UNION ALL
SELECT 'RolePermissions' AS [Object], COUNT(1) AS [Count] FROM RolePermissions
UNION ALL
SELECT 'Active Teachers' AS [Object], COUNT(1) AS [Count] FROM Teachers WHERE IsActive = 1
UNION ALL
SELECT 'Active Students' AS [Object], COUNT(1) AS [Count] FROM Students WHERE IsActive = 1;
GO

PRINT '>>> [SUCCESS] Migration_20261014_ConsolidatedUpdates executed successfully!';
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ==========================================================
-- 0. Ensure ClassSessions.SubjectId allows NULL
-- ==========================================================
IF EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS 
    WHERE TABLE_NAME = 'ClassSessions' AND COLUMN_NAME = 'SubjectId' AND IS_NULLABLE = 'NO'
)
BEGIN
    ALTER TABLE ClassSessions ALTER COLUMN SubjectId INT NULL;
END
GO

-- ==========================================================
-- 1. Get Students for Attendance Sheet (with existing session status if already taken)
-- ==========================================================
CREATE OR ALTER PROCEDURE [dbo].[sp_GetStudentsForAttendance]
    @BatchId INT,
    @SessionDate DATE,
    @SubjectId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @SessionId INT = NULL;
    DECLARE @Topic NVARCHAR(255) = NULL;
    DECLARE @TeacherId INT = NULL;

    -- Look for existing session for this batch and date
    SELECT TOP 1 
        @SessionId = SessionId,
        @Topic = Topic,
        @TeacherId = TeacherId
    FROM ClassSessions
    WHERE BatchId = @BatchId 
      AND SessionDate = @SessionDate
      AND (@SubjectId IS NULL OR SubjectId = @SubjectId OR SubjectId IS NULL);

    -- Return student roster for this batch with current/default status
    SELECT 
        s.StudentId,
        s.AdmissionNo,
        s.FirstName + ' ' + s.LastName AS FullName,
        s.Mobile,
        s.Email,
        s.ProfileImage,
        ISNULL(a.Status, 'Present') AS [Status],
        a.Remarks,
        @SessionId AS SessionId,
        @Topic AS Topic,
        @TeacherId AS TeacherId,
        CASE WHEN @SessionId IS NOT NULL THEN 1 ELSE 0 END AS IsAlreadyMarked
    FROM Enrollments e
    INNER JOIN Students s ON e.StudentId = s.StudentId
    LEFT JOIN Attendance a ON a.SessionId = @SessionId AND a.StudentId = s.StudentId
    WHERE e.BatchId = @BatchId
      AND e.Status = 'Active'
      AND s.IsActive = 1
    ORDER BY s.FirstName ASC, s.LastName ASC;
END
GO

-- ==========================================================
-- 2. Bulk Save / Update Attendance for a Batch
-- ==========================================================
CREATE OR ALTER PROCEDURE [dbo].[sp_SaveBatchAttendance]
    @BatchId INT,
    @SubjectId INT = NULL,
    @TeacherId INT = NULL,
    @SessionDate DATE,
    @Topic NVARCHAR(255) = NULL,
    @AttendanceJson NVARCHAR(MAX),
    @SessionId INT OUTPUT,
    @TotalMarked INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRANSACTION;
    BEGIN TRY
        -- Check if ClassSession already exists
        SELECT TOP 1 @SessionId = SessionId
        FROM ClassSessions
        WHERE BatchId = @BatchId 
          AND SessionDate = @SessionDate
          AND (@SubjectId IS NULL OR SubjectId = @SubjectId OR SubjectId IS NULL);

        IF @SessionId IS NOT NULL
        BEGIN
            -- Update existing session info
            UPDATE ClassSessions
            SET Topic = ISNULL(@Topic, Topic),
                TeacherId = ISNULL(@TeacherId, TeacherId),
                SubjectId = COALESCE(@SubjectId, SubjectId)
            WHERE SessionId = @SessionId;
        END
        ELSE
        BEGIN
            -- Create new session
            INSERT INTO ClassSessions (BatchId, SubjectId, TeacherId, SessionDate, Topic, CreatedAt)
            VALUES (@BatchId, @SubjectId, @TeacherId, @SessionDate, @Topic, GETDATE());

            SET @SessionId = SCOPE_IDENTITY();
        END

        -- Parse JSON and Upsert into Attendance table
        MERGE Attendance AS target
        USING (
            SELECT 
                StudentId,
                Status,
                Remarks
            FROM OPENJSON(@AttendanceJson)
            WITH (
                StudentId INT '$.StudentId',
                Status NVARCHAR(20) '$.Status',
                Remarks NVARCHAR(255) '$.Remarks'
            )
        ) AS source
        ON (target.SessionId = @SessionId AND target.StudentId = source.StudentId)
        WHEN MATCHED THEN
            UPDATE SET 
                target.Status = source.Status,
                target.Remarks = source.Remarks,
                target.MarkedAt = GETDATE()
        WHEN NOT MATCHED THEN
            INSERT (SessionId, StudentId, Status, Remarks, MarkedAt)
            VALUES (@SessionId, source.StudentId, source.Status, source.Remarks, GETDATE());

        SET @TotalMarked = @@ROWCOUNT;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- ==========================================================
-- 3. Master Paged Attendance Records (For Admin & Teacher Grids)
-- ==========================================================
CREATE OR ALTER PROCEDURE [dbo].[sp_GetPagedAttendanceRecords]
    @SearchTerm NVARCHAR(100) = NULL,
    @BatchId INT = NULL,
    @CourseId INT = NULL,
    @FromDate DATE = NULL,
    @ToDate DATE = NULL,
    @Status NVARCHAR(20) = NULL,
    @TeacherId INT = NULL,
    @PageNumber INT = 1,
    @PageSize INT = 10,
    @SortColumn NVARCHAR(50) = 'SessionDate',
    @SortDirection NVARCHAR(10) = 'DESC',
    @TotalCount INT OUTPUT,
    @TotalPresent INT OUTPUT,
    @TotalAbsent INT OUTPUT,
    @TotalLate INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @SearchTerm = LTRIM(RTRIM(@SearchTerm));
    IF @SearchTerm = '' SET @SearchTerm = NULL;
    IF @Status = '' OR @Status = 'All' SET @Status = NULL;

    IF @PageNumber < 1 SET @PageNumber = 1;
    IF @PageSize < 1 SET @PageSize = 10;

    -- Metrics calculation for matched criteria
    SELECT 
        @TotalCount = COUNT(1),
        @TotalPresent = SUM(CASE WHEN a.Status = 'Present' THEN 1 ELSE 0 END),
        @TotalAbsent = SUM(CASE WHEN a.Status = 'Absent' THEN 1 ELSE 0 END),
        @TotalLate = SUM(CASE WHEN a.Status IN ('Late', 'Excused') THEN 1 ELSE 0 END)
    FROM Attendance a
    INNER JOIN ClassSessions cs ON a.SessionId = cs.SessionId
    INNER JOIN Batches b ON cs.BatchId = b.BatchId
    INNER JOIN Courses c ON b.CourseId = c.CourseId
    LEFT JOIN Subjects sub ON cs.SubjectId = sub.SubjectId
    LEFT JOIN Teachers t ON cs.TeacherId = t.TeacherId
    INNER JOIN Students s ON a.StudentId = s.StudentId
    WHERE 
        (@BatchId IS NULL OR cs.BatchId = @BatchId)
        AND (@CourseId IS NULL OR b.CourseId = @CourseId)
        AND (@TeacherId IS NULL OR cs.TeacherId = @TeacherId)
        AND (@FromDate IS NULL OR cs.SessionDate >= @FromDate)
        AND (@ToDate IS NULL OR cs.SessionDate <= @ToDate)
        AND (@Status IS NULL OR a.Status = @Status)
        AND (
            @SearchTerm IS NULL 
            OR s.FirstName LIKE '%' + @SearchTerm + '%'
            OR s.LastName LIKE '%' + @SearchTerm + '%'
            OR (s.FirstName + ' ' + s.LastName) LIKE '%' + @SearchTerm + '%'
            OR s.AdmissionNo LIKE '%' + @SearchTerm + '%'
            OR b.BatchName LIKE '%' + @SearchTerm + '%'
            OR c.CourseName LIKE '%' + @SearchTerm + '%'
        );

    -- Paged rows
    SELECT 
        a.AttendanceId,
        a.SessionId,
        cs.SessionDate,
        cs.Topic,
        cs.BatchId,
        b.BatchName,
        c.CourseName,
        ISNULL(sub.SubjectName, 'General') AS SubjectName,
        ISNULL(t.FirstName + ' ' + t.LastName, 'Staff') AS TeacherName,
        s.StudentId,
        s.AdmissionNo,
        s.FirstName + ' ' + s.LastName AS StudentName,
        s.ProfileImage,
        a.Status,
        a.Remarks,
        a.MarkedAt
    FROM Attendance a
    INNER JOIN ClassSessions cs ON a.SessionId = cs.SessionId
    INNER JOIN Batches b ON cs.BatchId = b.BatchId
    INNER JOIN Courses c ON b.CourseId = c.CourseId
    LEFT JOIN Subjects sub ON cs.SubjectId = sub.SubjectId
    LEFT JOIN Teachers t ON cs.TeacherId = t.TeacherId
    INNER JOIN Students s ON a.StudentId = s.StudentId
    WHERE 
        (@BatchId IS NULL OR cs.BatchId = @BatchId)
        AND (@CourseId IS NULL OR b.CourseId = @CourseId)
        AND (@TeacherId IS NULL OR cs.TeacherId = @TeacherId)
        AND (@FromDate IS NULL OR cs.SessionDate >= @FromDate)
        AND (@ToDate IS NULL OR cs.SessionDate <= @ToDate)
        AND (@Status IS NULL OR a.Status = @Status)
        AND (
            @SearchTerm IS NULL 
            OR s.FirstName LIKE '%' + @SearchTerm + '%'
            OR s.LastName LIKE '%' + @SearchTerm + '%'
            OR (s.FirstName + ' ' + s.LastName) LIKE '%' + @SearchTerm + '%'
            OR s.AdmissionNo LIKE '%' + @SearchTerm + '%'
            OR b.BatchName LIKE '%' + @SearchTerm + '%'
            OR c.CourseName LIKE '%' + @SearchTerm + '%'
        )
    ORDER BY
        CASE WHEN @SortDirection = 'ASC' AND @SortColumn = 'SessionDate' THEN cs.SessionDate END ASC,
        CASE WHEN @SortDirection = 'DESC' AND @SortColumn = 'SessionDate' THEN cs.SessionDate END DESC,
        CASE WHEN @SortDirection = 'ASC' AND @SortColumn = 'StudentName' THEN s.FirstName END ASC,
        CASE WHEN @SortDirection = 'DESC' AND @SortColumn = 'StudentName' THEN s.FirstName END DESC,
        CASE WHEN @SortDirection = 'ASC' AND @SortColumn = 'AdmissionNo' THEN s.AdmissionNo END ASC,
        CASE WHEN @SortDirection = 'DESC' AND @SortColumn = 'AdmissionNo' THEN s.AdmissionNo END DESC,
        CASE WHEN @SortDirection = 'ASC' AND @SortColumn = 'BatchName' THEN b.BatchName END ASC,
        CASE WHEN @SortDirection = 'DESC' AND @SortColumn = 'BatchName' THEN b.BatchName END DESC,
        CASE WHEN @SortDirection = 'ASC' AND @SortColumn = 'Status' THEN a.Status END ASC,
        CASE WHEN @SortDirection = 'DESC' AND @SortColumn = 'Status' THEN a.Status END DESC,
        CASE WHEN @SortColumn IS NULL OR @SortColumn = '' THEN cs.SessionDate END DESC,
        a.AttendanceId DESC
    OFFSET (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- ==========================================================
-- 4. Student Side: Personal Paged Attendance Record with Overall Stats
-- ==========================================================
CREATE OR ALTER PROCEDURE [dbo].[sp_GetPagedStudentAttendance]
    @StudentId INT,
    @FromDate DATE = NULL,
    @ToDate DATE = NULL,
    @Status NVARCHAR(20) = NULL,
    @PageNumber INT = 1,
    @PageSize INT = 10,
    @SortColumn NVARCHAR(50) = 'SessionDate',
    @SortDirection NVARCHAR(10) = 'DESC',
    @TotalCount INT OUTPUT,
    @TotalClasses INT OUTPUT,
    @AttendedClasses INT OUTPUT,
    @AbsentClasses INT OUTPUT,
    @LateClasses INT OUTPUT,
    @AttendancePercentage DECIMAL(5,2) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF @Status = '' OR @Status = 'All' SET @Status = NULL;
    IF @PageNumber < 1 SET @PageNumber = 1;
    IF @PageSize < 1 SET @PageSize = 10;

    -- Calculate lifetime / period statistics for this student
    SELECT 
        @TotalClasses = COUNT(1),
        @AttendedClasses = SUM(CASE WHEN a.Status IN ('Present', 'Late') THEN 1 ELSE 0 END),
        @AbsentClasses = SUM(CASE WHEN a.Status = 'Absent' THEN 1 ELSE 0 END),
        @LateClasses = SUM(CASE WHEN a.Status = 'Late' THEN 1 ELSE 0 END)
    FROM Attendance a
    INNER JOIN ClassSessions cs ON a.SessionId = cs.SessionId
    WHERE a.StudentId = @StudentId;

    IF @TotalClasses > 0
        SET @AttendancePercentage = ROUND((CAST(@AttendedClasses AS DECIMAL(7,2)) / CAST(@TotalClasses AS DECIMAL(7,2))) * 100.0, 2);
    ELSE
        SET @AttendancePercentage = 0.00;

    -- Count matching filtered records
    SELECT @TotalCount = COUNT(1)
    FROM Attendance a
    INNER JOIN ClassSessions cs ON a.SessionId = cs.SessionId
    INNER JOIN Batches b ON cs.BatchId = b.BatchId
    LEFT JOIN Subjects sub ON cs.SubjectId = sub.SubjectId
    WHERE a.StudentId = @StudentId
      AND (@FromDate IS NULL OR cs.SessionDate >= @FromDate)
      AND (@ToDate IS NULL OR cs.SessionDate <= @ToDate)
      AND (@Status IS NULL OR a.Status = @Status);

    -- Paged records
    SELECT 
        a.AttendanceId,
        a.SessionId,
        cs.SessionDate,
        cs.Topic,
        b.BatchName,
        ISNULL(sub.SubjectName, 'General Session') AS SubjectName,
        ISNULL(t.FirstName + ' ' + t.LastName, 'Faculty') AS TeacherName,
        a.Status,
        a.Remarks,
        a.MarkedAt
    FROM Attendance a
    INNER JOIN ClassSessions cs ON a.SessionId = cs.SessionId
    INNER JOIN Batches b ON cs.BatchId = b.BatchId
    LEFT JOIN Subjects sub ON cs.SubjectId = sub.SubjectId
    LEFT JOIN Teachers t ON cs.TeacherId = t.TeacherId
    WHERE a.StudentId = @StudentId
      AND (@FromDate IS NULL OR cs.SessionDate >= @FromDate)
      AND (@ToDate IS NULL OR cs.SessionDate <= @ToDate)
      AND (@Status IS NULL OR a.Status = @Status)
    ORDER BY
        CASE WHEN @SortDirection = 'ASC' AND @SortColumn = 'SessionDate' THEN cs.SessionDate END ASC,
        CASE WHEN @SortDirection = 'DESC' AND @SortColumn = 'SessionDate' THEN cs.SessionDate END DESC,
        CASE WHEN @SortDirection = 'ASC' AND @SortColumn = 'Status' THEN a.Status END ASC,
        CASE WHEN @SortDirection = 'DESC' AND @SortColumn = 'Status' THEN a.Status END DESC,
        CASE WHEN @SortColumn IS NULL OR @SortColumn = '' THEN cs.SessionDate END DESC,
        a.AttendanceId DESC
    OFFSET (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- ==========================================================
-- 5. Overall Today's Dashboard Metrics for Attendance
-- ==========================================================
CREATE OR ALTER PROCEDURE [dbo].[sp_GetAttendanceDashboardStats]
    @TeacherId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Today DATE = CAST(GETDATE() AS DATE);
    DECLARE @SessionsToday INT = 0;
    DECLARE @TotalMarkedToday INT = 0;
    DECLARE @PresentToday INT = 0;
    DECLARE @AbsentToday INT = 0;
    DECLARE @LateToday INT = 0;
    DECLARE @OverallRate DECIMAL(5,2) = 0.00;

    SELECT 
        @SessionsToday = COUNT(DISTINCT cs.SessionId),
        @TotalMarkedToday = COUNT(a.AttendanceId),
        @PresentToday = SUM(CASE WHEN a.Status = 'Present' THEN 1 ELSE 0 END),
        @AbsentToday = SUM(CASE WHEN a.Status = 'Absent' THEN 1 ELSE 0 END),
        @LateToday = SUM(CASE WHEN a.Status IN ('Late', 'Excused') THEN 1 ELSE 0 END)
    FROM ClassSessions cs
    LEFT JOIN Attendance a ON cs.SessionId = a.SessionId
    WHERE cs.SessionDate = @Today
      AND (@TeacherId IS NULL OR cs.TeacherId = @TeacherId);

    IF @TotalMarkedToday > 0
        SET @OverallRate = ROUND((CAST((@PresentToday + @LateToday) AS DECIMAL(7,2)) / CAST(@TotalMarkedToday AS DECIMAL(7,2))) * 100.0, 2);

    SELECT 
        @Today AS TodayDate,
        ISNULL(@SessionsToday, 0) AS SessionsToday,
        ISNULL(@TotalMarkedToday, 0) AS TotalMarkedToday,
        ISNULL(@PresentToday, 0) AS PresentToday,
        ISNULL(@AbsentToday, 0) AS AbsentToday,
        ISNULL(@LateToday, 0) AS LateToday,
        ISNULL(@OverallRate, 0.00) AS OverallRate;
END
GO
