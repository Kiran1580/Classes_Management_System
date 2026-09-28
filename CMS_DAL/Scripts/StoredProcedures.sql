-- ==========================================================
-- Stored Procedures Script: Classes & Coaching Management System
-- Enterprise ADO.NET Stored Procedures
-- ==========================================================

USE ClassesManagementDb;
GO

-- ==========================================================
-- 1. USERS & AUTHENTICATION STORED PROCEDURES
-- ==========================================================

-- Get User By Email
CREATE OR ALTER PROCEDURE sp_GetUserByEmail
    @Email NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        u.UserId, 
        u.FullName, 
        u.Email, 
        u.Mobile, 
        u.PasswordHash, 
        u.RoleId, 
        r.RoleName, 
        u.IsActive, 
        u.CreatedAt, 
        u.UpdatedAt
    FROM Users u
    INNER JOIN Roles r ON u.RoleId = r.RoleId
    WHERE LOWER(u.Email) = LOWER(@Email);
END
GO

-- Get User By Id
CREATE OR ALTER PROCEDURE sp_GetUserById
    @UserId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        u.UserId, 
        u.FullName, 
        u.Email, 
        u.Mobile, 
        u.PasswordHash, 
        u.RoleId, 
        r.RoleName, 
        u.IsActive, 
        u.CreatedAt, 
        u.UpdatedAt
    FROM Users u
    INNER JOIN Roles r ON u.RoleId = r.RoleId
    WHERE u.UserId = @UserId;
END
GO

-- Create User
CREATE OR ALTER PROCEDURE sp_CreateUser
    @FullName NVARCHAR(100),
    @Email NVARCHAR(100),
    @Mobile NVARCHAR(20) = NULL,
    @PasswordHash NVARCHAR(255),
    @RoleId INT,
    @IsActive BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO Users (FullName, Email, Mobile, PasswordHash, RoleId, IsActive, CreatedAt)
    VALUES (@FullName, @Email, @Mobile, @PasswordHash, @RoleId, @IsActive, GETDATE());

    SELECT CAST(SCOPE_IDENTITY() AS INT) AS NewUserId;
END
GO

-- Update Password
CREATE OR ALTER PROCEDURE sp_UpdateUserPassword
    @UserId INT,
    @PasswordHash NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE Users
    SET PasswordHash = @PasswordHash,
        UpdatedAt = GETDATE()
    WHERE UserId = @UserId;

    SELECT @@ROWCOUNT AS RowsAffected;
END
GO

-- Check Email Exists
CREATE OR ALTER PROCEDURE sp_CheckEmailExists
    @Email NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT COUNT(1) AS EmailCount
    FROM Users
    WHERE LOWER(Email) = LOWER(@Email);
END
GO

-- Get Users by Role Name
CREATE OR ALTER PROCEDURE sp_GetUsersByRole
    @RoleName NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        u.UserId, 
        u.FullName, 
        u.Email, 
        u.Mobile, 
        u.PasswordHash, 
        u.RoleId, 
        r.RoleName, 
        u.IsActive, 
        u.CreatedAt, 
        u.UpdatedAt
    FROM Users u
    INNER JOIN Roles r ON u.RoleId = r.RoleId
    WHERE r.RoleName = @RoleName
    ORDER BY u.FullName;
END
GO

-- ==========================================================
-- 2. ROLES STORED PROCEDURES
-- ==========================================================

-- Get All Roles
CREATE OR ALTER PROCEDURE sp_GetAllRoles
AS
BEGIN
    SET NOCOUNT ON;

    SELECT RoleId, RoleName 
    FROM Roles 
    ORDER BY RoleId;
END
GO

-- Get Role By Id
CREATE OR ALTER PROCEDURE sp_GetRoleById
    @RoleId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT RoleId, RoleName 
    FROM Roles 
    WHERE RoleId = @RoleId;
END
GO

-- Get Role By Name
CREATE OR ALTER PROCEDURE sp_GetRoleByName
    @RoleName NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT RoleId, RoleName 
    FROM Roles 
    WHERE LOWER(RoleName) = LOWER(@RoleName);
END
GO

-- ==========================================================
-- 3. ACADEMIC YEARS STORED PROCEDURES
-- ==========================================================

-- Get Current Academic Year
CREATE OR ALTER PROCEDURE sp_GetCurrentAcademicYear
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP 1 
        AcademicYearId, 
        YearName, 
        StartDate, 
        EndDate, 
        IsCurrent, 
        CreatedAt
    FROM AcademicYears
    WHERE IsCurrent = 1
    ORDER BY AcademicYearId DESC;
END
GO

-- Get All Academic Years
CREATE OR ALTER PROCEDURE sp_GetAllAcademicYears
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        AcademicYearId, 
        YearName, 
        StartDate, 
        EndDate, 
        IsCurrent, 
        CreatedAt
    FROM AcademicYears
    ORDER BY StartDate DESC;
END
GO

-- Create Academic Year
CREATE OR ALTER PROCEDURE sp_CreateAcademicYear
    @YearName NVARCHAR(50),
    @StartDate DATE,
    @EndDate DATE,
    @IsCurrent BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    IF @IsCurrent = 1
    BEGIN
        UPDATE AcademicYears SET IsCurrent = 0;
    END

    INSERT INTO AcademicYears (YearName, StartDate, EndDate, IsCurrent, CreatedAt)
    VALUES (@YearName, @StartDate, @EndDate, @IsCurrent, GETDATE());

    SELECT CAST(SCOPE_IDENTITY() AS INT) AS NewAcademicYearId;
END
GO

-- Set Current Academic Year
CREATE OR ALTER PROCEDURE sp_SetCurrentAcademicYear
    @AcademicYearId INT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE AcademicYears SET IsCurrent = 0;
    UPDATE AcademicYears SET IsCurrent = 1 WHERE AcademicYearId = @AcademicYearId;

    SELECT @@ROWCOUNT AS RowsAffected;
END
GO

-- ==========================================================
-- 4. DASHBOARDS METRICS STORED PROCEDURES
-- ==========================================================

-- Get Admin Dashboard Stats
CREATE OR ALTER PROCEDURE sp_GetAdminDashboardStats
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        (SELECT COUNT(1) FROM Students WHERE IsActive = 1) AS TotalStudents,
        (SELECT COUNT(1) FROM Teachers WHERE IsActive = 1) AS TotalTeachers,
        (SELECT COUNT(1) FROM Courses WHERE IsActive = 1) AS TotalCourses,
        (SELECT COUNT(1) FROM Batches WHERE Status = 'Active') AS TotalBatches,
        (SELECT COUNT(1) FROM Payments WHERE Status = 'Pending') AS PendingFeeApprovals,
        ISNULL((SELECT SUM(Amount) FROM Payments WHERE Status = 'Approved'), 0) AS TotalCollectedRevenue,
        ISNULL((SELECT SUM(BalanceAmount) FROM FeeInstallments WHERE Status <> 'Paid'), 0) AS PendingFeesAmount,
        (SELECT COUNT(1) FROM Inquiries WHERE Status NOT IN ('Enrolled', 'Dropped')) AS ActiveInquiries;
END
GO

-- Get Teacher Dashboard Stats
CREATE OR ALTER PROCEDURE sp_GetTeacherDashboardStats
    @UserId INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @TeacherId INT = (SELECT TeacherId FROM Teachers WHERE UserId = @UserId);

    SELECT 
        (SELECT COUNT(DISTINCT BatchId) FROM BatchSubjects WHERE TeacherId = @TeacherId) AS MyBatchesCount,
        ISNULL((SELECT COUNT(DISTINCT e.StudentId) 
                FROM Enrollments e 
                INNER JOIN BatchSubjects bs ON e.BatchId = bs.BatchId 
                WHERE bs.TeacherId = @TeacherId AND e.Status = 'Active'), 0) AS TotalStudentsEnrolled,
        (SELECT COUNT(1) FROM ClassSessions 
         WHERE TeacherId = @TeacherId AND SessionDate = CAST(GETDATE() AS DATE)) AS TodayLecturesCount,
        (SELECT COUNT(1) FROM Exams e
         INNER JOIN BatchSubjects bs ON e.BatchId = bs.BatchId
         WHERE bs.TeacherId = @TeacherId AND e.ExamDate >= CAST(GETDATE() AS DATE)) AS UpcomingExamsCount;
END
GO

-- Get Student Dashboard Stats
CREATE OR ALTER PROCEDURE sp_GetStudentDashboardStats
    @UserId INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @StudentId INT = (SELECT StudentId FROM Students WHERE UserId = @UserId);

    SELECT 
        ISNULL((SELECT TOP 1 b.BatchName 
                FROM Enrollments e 
                INNER JOIN Batches b ON e.BatchId = b.BatchId 
                WHERE e.StudentId = @StudentId AND e.Status = 'Active' 
                ORDER BY e.EnrollmentDate DESC), 'Not Assigned') AS BatchName,

        ISNULL((SELECT TOP 1 c.CourseName 
                FROM Enrollments e 
                INNER JOIN Batches b ON e.BatchId = b.BatchId 
                INNER JOIN Courses c ON b.CourseId = c.CourseId
                WHERE e.StudentId = @StudentId AND e.Status = 'Active' 
                ORDER BY e.EnrollmentDate DESC), 'N/A') AS CourseName,

        ISNULL((SELECT SUM(sf.FinalAmount) FROM StudentFees sf WHERE sf.StudentId = @StudentId), 0) AS TotalFees,

        ISNULL((SELECT SUM(p.Amount) 
                FROM Payments p 
                INNER JOIN StudentFees sf ON p.StudentFeeId = sf.StudentFeeId 
                WHERE sf.StudentId = @StudentId AND p.Status = 'Approved'), 0) AS PaidFees,

        ISNULL((SELECT SUM(fi.BalanceAmount) 
                FROM FeeInstallments fi 
                INNER JOIN StudentFees sf ON fi.StudentFeeId = sf.StudentFeeId 
                WHERE sf.StudentId = @StudentId AND fi.Status <> 'Paid'), 0) AS PendingFees,

        (SELECT COUNT(1) 
         FROM Payments p 
         INNER JOIN StudentFees sf ON p.StudentFeeId = sf.StudentFeeId 
         WHERE sf.StudentId = @StudentId AND p.Status = 'Pending') AS PendingPaymentReviews,

        CASE 
            WHEN (SELECT COUNT(1) FROM Attendance WHERE StudentId = @StudentId) = 0 THEN 100.0
            ELSE (CAST((SELECT COUNT(1) FROM Attendance WHERE StudentId = @StudentId AND Status = 'Present') AS DECIMAL(5,2)) * 100.0) 
                 / CAST((SELECT COUNT(1) FROM Attendance WHERE StudentId = @StudentId) AS DECIMAL(5,2))
        END AS AttendancePercentage;
END
GO

-- ==========================================================
-- 5. REGISTRATION & APPROVAL STORED PROCEDURES
-- ==========================================================

-- Register Student
CREATE OR ALTER PROCEDURE sp_RegisterStudent
    @FullName NVARCHAR(100),
    @Email NVARCHAR(100),
    @Mobile NVARCHAR(20) = NULL,
    @PasswordHash NVARCHAR(255),
    @ParentName NVARCHAR(100) = NULL,
    @ParentMobile NVARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    IF EXISTS (SELECT 1 FROM Users WHERE LOWER(Email) = LOWER(LTRIM(RTRIM(@Email))))
    BEGIN
        SELECT -1 AS UserId;
        RETURN;
    END

    DECLARE @RoleId INT = 3;
    DECLARE @UserId INT;

    INSERT INTO Users (FullName, Email, Mobile, PasswordHash, RoleId, IsActive, CreatedAt)
    VALUES (LTRIM(RTRIM(@FullName)), LOWER(LTRIM(RTRIM(@Email))), @Mobile, @PasswordHash, @RoleId, 0, GETDATE());

    SET @UserId = SCOPE_IDENTITY();

    DECLARE @AdmissionNo NVARCHAR(50);
    SET @AdmissionNo = 'STU' + CAST(YEAR(GETDATE()) AS NVARCHAR(4)) + '-' + RIGHT('0000' + CAST(@UserId AS NVARCHAR(10)), 4);

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

    INSERT INTO Students (UserId, AdmissionNo, FirstName, LastName, Mobile, Email, ParentName, ParentMobile, AdmissionDate, IsActive, CreatedAt)
    VALUES (@UserId, @AdmissionNo, @FirstName, @LastName, @Mobile, LOWER(LTRIM(RTRIM(@Email))), @ParentName, @ParentMobile, CAST(GETDATE() AS DATE), 0, GETDATE());

    SELECT @UserId AS UserId;
END
GO

-- Register Teacher
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

    IF EXISTS (SELECT 1 FROM Users WHERE LOWER(Email) = LOWER(LTRIM(RTRIM(@Email))))
    BEGIN
        SELECT -1 AS UserId;
        RETURN;
    END

    DECLARE @RoleId INT = 2;
    DECLARE @UserId INT;

    INSERT INTO Users (FullName, Email, Mobile, PasswordHash, RoleId, IsActive, CreatedAt)
    VALUES (LTRIM(RTRIM(@FullName)), LOWER(LTRIM(RTRIM(@Email))), @Mobile, @PasswordHash, @RoleId, 0, GETDATE());

    SET @UserId = SCOPE_IDENTITY();

    DECLARE @EmployeeCode NVARCHAR(50);
    SET @EmployeeCode = 'TCH' + CAST(YEAR(GETDATE()) AS NVARCHAR(4)) + '-' + RIGHT('0000' + CAST(@UserId AS NVARCHAR(10)), 4);

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

    INSERT INTO Teachers (UserId, EmployeeCode, FirstName, LastName, Mobile, Email, Qualification, JoiningDate, IsActive, CreatedAt)
    VALUES (@UserId, @EmployeeCode, @FirstName, @LastName, @Mobile, LOWER(LTRIM(RTRIM(@Email))), @Qualification, CAST(GETDATE() AS DATE), 0, GETDATE());

    SELECT @UserId AS UserId;
END
GO

-- Get Pending Registrations
CREATE OR ALTER PROCEDURE sp_GetPendingRegistrations
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        u.UserId,
        u.FullName,
        u.Email,
        u.Mobile,
        u.RoleId,
        r.RoleName,
        u.IsActive,
        u.CreatedAt,
        COALESCE(t.Qualification, s.ParentName, '-') AS ExtraInfo,
        COALESCE(t.EmployeeCode, s.AdmissionNo, '-') AS ReferenceCode
    FROM Users u
    INNER JOIN Roles r ON u.RoleId = r.RoleId
    LEFT JOIN Students s ON u.UserId = s.UserId
    LEFT JOIN Teachers t ON u.UserId = t.UserId
    WHERE u.IsActive = 0
    ORDER BY u.CreatedAt DESC;
END
GO

-- Approve User
CREATE OR ALTER PROCEDURE sp_ApproveUser
    @UserId INT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE Users 
    SET IsActive = 1, UpdatedAt = GETDATE() 
    WHERE UserId = @UserId;

    UPDATE Students 
    SET IsActive = 1 
    WHERE UserId = @UserId;

    UPDATE Teachers 
    SET IsActive = 1 
    WHERE UserId = @UserId;

    SELECT 1 AS Result;
END
GO

-- Reject User
CREATE OR ALTER PROCEDURE sp_RejectUser
    @UserId INT
AS
BEGIN
    SET NOCOUNT ON;

    DELETE FROM Students WHERE UserId = @UserId;
    DELETE FROM Teachers WHERE UserId = @UserId;
    DELETE FROM Users WHERE UserId = @UserId;

    SELECT 1 AS Result;
END
GO
