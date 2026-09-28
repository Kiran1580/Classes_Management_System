-- ==========================================================
-- Registration & User Approval Stored Procedures
-- ==========================================================

USE ClassesManagementDb;
GO

-- 1. Register Student
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
    
    -- Check if email exists
    IF EXISTS (SELECT 1 FROM Users WHERE LOWER(Email) = LOWER(LTRIM(RTRIM(@Email))))
    BEGIN
        SELECT -1 AS UserId;
        RETURN;
    END

    DECLARE @RoleId INT = 3; -- Student
    DECLARE @UserId INT;

    INSERT INTO Users (FullName, Email, Mobile, PasswordHash, RoleId, IsActive, CreatedAt)
    VALUES (LTRIM(RTRIM(@FullName)), LOWER(LTRIM(RTRIM(@Email))), @Mobile, @PasswordHash, @RoleId, 0, GETDATE());

    SET @UserId = SCOPE_IDENTITY();

    -- Generate Admission No (e.g. STU2026-0001)
    DECLARE @AdmissionNo NVARCHAR(50);
    SET @AdmissionNo = 'STU' + CAST(YEAR(GETDATE()) AS NVARCHAR(4)) + '-' + RIGHT('0000' + CAST(@UserId AS NVARCHAR(10)), 4);

    -- Split name for First & Last
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

-- 2. Register Teacher
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

    -- Check if email exists
    IF EXISTS (SELECT 1 FROM Users WHERE LOWER(Email) = LOWER(LTRIM(RTRIM(@Email))))
    BEGIN
        SELECT -1 AS UserId;
        RETURN;
    END

    DECLARE @RoleId INT = 2; -- Teacher
    DECLARE @UserId INT;

    INSERT INTO Users (FullName, Email, Mobile, PasswordHash, RoleId, IsActive, CreatedAt)
    VALUES (LTRIM(RTRIM(@FullName)), LOWER(LTRIM(RTRIM(@Email))), @Mobile, @PasswordHash, @RoleId, 0, GETDATE());

    SET @UserId = SCOPE_IDENTITY();

    -- Generate Employee Code (e.g. TCH2026-0001)
    DECLARE @EmployeeCode NVARCHAR(50);
    SET @EmployeeCode = 'TCH' + CAST(YEAR(GETDATE()) AS NVARCHAR(4)) + '-' + RIGHT('0000' + CAST(@UserId AS NVARCHAR(10)), 4);

    -- Split name for First & Last
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

-- 3. Get Pending Registrations
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

-- 4. Approve User
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

-- 5. Reject User
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
