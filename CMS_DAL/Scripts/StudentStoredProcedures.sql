USE ClassesManagementDb;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- ==========================================================
-- 1. Helper: Get Next Auto-Generated Admission Number
-- ==========================================================
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

-- ==========================================================
-- 2. Get Batches by Course Id (For Dynamic AJAX Dropdowns)
-- ==========================================================
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

-- ==========================================================
-- 3. Get Student Stats
-- ==========================================================
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

-- ==========================================================
-- 4. Get Paged Students (Search, Multi-Filter, Sort, Pagination)
-- ==========================================================
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

-- ==========================================================
-- 5. Get Student By Id (Full Details & Current Enrollment)
-- ==========================================================
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

-- ==========================================================
-- 5B. Get Student By User Id (For Student Portal & My Profile)
-- ==========================================================
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

-- ==========================================================
-- 5C. Update Student Self-Profile (DOB, Gender, Address, Photo)
-- ==========================================================
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

-- ==========================================================
-- 6. Create Student Admission (Transactional Student + Enrollment)
-- ==========================================================
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

        -- Insert Student
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

-- ==========================================================
-- 7. Update Student Details & Batch Enrollment
-- ==========================================================
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

-- ==========================================================
-- 8. Delete Or Deactivate Student
-- ==========================================================
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
