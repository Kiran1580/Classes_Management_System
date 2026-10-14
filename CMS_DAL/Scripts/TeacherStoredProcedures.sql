-- ==========================================================
-- Stored Procedures for Teacher / Faculty Management
-- Database: ClassesManagementDb
-- ==========================================================

USE ClassesManagementDb;
GO

-- ==========================================================
-- 1. Get Next Employee Code (e.g. TCH-2026-0001)
-- ==========================================================
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

-- ==========================================================
-- 2. Teacher Stats
-- ==========================================================
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

-- ==========================================================
-- 3. Get Paged Teachers (Search, Filter, Sort, Pagination)
-- ==========================================================
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

-- ==========================================================
-- 4. Get Teacher By Id
-- ==========================================================
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

-- ==========================================================
-- 5. Get Teacher By User Id
-- ==========================================================
CREATE OR ALTER PROCEDURE sp_GetTeacherByUserId
    @UserId INT
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
    WHERE t.UserId = @UserId;
END;
GO

-- ==========================================================
-- 6. Get Batches Assigned to Teacher
-- ==========================================================
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

-- ==========================================================
-- 7. Create Teacher (Transactional: Users + Teachers)
-- ==========================================================
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

-- ==========================================================
-- 8. Update Teacher
-- ==========================================================
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

-- ==========================================================
-- 9. Delete Teacher (with strict FK Dependency checks)
-- ==========================================================
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

-- ==========================================================
-- 10. Get All Active Teachers (for Dropdowns)
-- ==========================================================
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
