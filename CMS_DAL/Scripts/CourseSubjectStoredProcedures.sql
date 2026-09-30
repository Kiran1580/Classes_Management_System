-- ==========================================================
-- Phase 2 - Step 1: Courses & Subjects Stored Procedures
-- ==========================================================

USE ClassesManagementDb;
GO

-- 1. Create CourseSubjects table if not exists
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'CourseSubjects')
BEGIN
    CREATE TABLE CourseSubjects (
        CourseSubjectId INT IDENTITY(1,1) PRIMARY KEY,
        CourseId INT NOT NULL,
        SubjectId INT NOT NULL,
        CreatedAt DATETIME2 NOT NULL DEFAULT GETDATE(),
        CONSTRAINT FK_CourseSubjects_Courses FOREIGN KEY (CourseId) REFERENCES Courses(CourseId) ON DELETE CASCADE,
        CONSTRAINT FK_CourseSubjects_Subjects FOREIGN KEY (SubjectId) REFERENCES Subjects(SubjectId) ON DELETE CASCADE,
        CONSTRAINT UQ_CourseSubjects UNIQUE (CourseId, SubjectId)
    );
END
GO

-- 2. Get All Courses (with subjects and active batches count)
CREATE OR ALTER PROCEDURE sp_GetAllCourses
AS
BEGIN
    SET NOCOUNT ON;

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
    ORDER BY c.CourseName ASC;
END
GO

-- 3. Get Course By Id
CREATE OR ALTER PROCEDURE sp_GetCourseById
    @CourseId INT
AS
BEGIN
    SET NOCOUNT ON;

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
    WHERE c.CourseId = @CourseId;
END
GO

-- 4. Create Course
CREATE OR ALTER PROCEDURE sp_CreateCourse
    @CourseName NVARCHAR(100),
    @Description NVARCHAR(500) = NULL,
    @Duration NVARCHAR(50) = NULL,
    @IsActive BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM Courses WHERE LOWER(LTRIM(RTRIM(CourseName))) = LOWER(LTRIM(RTRIM(@CourseName))))
    BEGIN
        SELECT -1 AS CourseId; -- Already exists
        RETURN;
    END

    INSERT INTO Courses (CourseName, Description, Duration, IsActive, CreatedAt)
    VALUES (LTRIM(RTRIM(@CourseName)), @Description, @Duration, @IsActive, GETDATE());

    SELECT SCOPE_IDENTITY() AS CourseId;
END
GO

-- 5. Update Course
CREATE OR ALTER PROCEDURE sp_UpdateCourse
    @CourseId INT,
    @CourseName NVARCHAR(100),
    @Description NVARCHAR(500) = NULL,
    @Duration NVARCHAR(50) = NULL,
    @IsActive BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM Courses WHERE LOWER(LTRIM(RTRIM(CourseName))) = LOWER(LTRIM(RTRIM(@CourseName))) AND CourseId <> @CourseId)
    BEGIN
        SELECT -1 AS Result; -- Name conflict
        RETURN;
    END

    UPDATE Courses
    SET CourseName = LTRIM(RTRIM(@CourseName)),
        Description = @Description,
        Duration = @Duration,
        IsActive = @IsActive
    WHERE CourseId = @CourseId;

    SELECT 1 AS Result;
END
GO

-- 6. Delete Course
CREATE OR ALTER PROCEDURE sp_DeleteCourse
    @CourseId INT
AS
BEGIN
    SET NOCOUNT ON;

    -- If batches exist for this course, don't hard delete, just deactivate
    IF EXISTS (SELECT 1 FROM Batches WHERE CourseId = @CourseId)
    BEGIN
        UPDATE Courses SET IsActive = 0 WHERE CourseId = @CourseId;
        SELECT 2 AS Result; -- Soft deleted (deactivated due to batch references)
        RETURN;
    END

    DELETE FROM CourseSubjects WHERE CourseId = @CourseId;
    DELETE FROM Courses WHERE CourseId = @CourseId;

    SELECT 1 AS Result; -- Hard deleted
END
GO

-- 7. Get All Subjects
CREATE OR ALTER PROCEDURE sp_GetAllSubjects
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        s.SubjectId,
        s.SubjectName,
        s.Description,
        s.IsActive,
        s.CreatedAt,
        (SELECT COUNT(1) FROM CourseSubjects cs WHERE cs.SubjectId = s.SubjectId) AS CoursesCount
    FROM Subjects s
    ORDER BY s.SubjectName ASC;
END
GO

-- 8. Get Subject By Id
CREATE OR ALTER PROCEDURE sp_GetSubjectById
    @SubjectId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        s.SubjectId,
        s.SubjectName,
        s.Description,
        s.IsActive,
        s.CreatedAt,
        (SELECT COUNT(1) FROM CourseSubjects cs WHERE cs.SubjectId = s.SubjectId) AS CoursesCount
    FROM Subjects s
    WHERE s.SubjectId = @SubjectId;
END
GO

-- 9. Create Subject
CREATE OR ALTER PROCEDURE sp_CreateSubject
    @SubjectName NVARCHAR(100),
    @Description NVARCHAR(500) = NULL,
    @IsActive BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM Subjects WHERE LOWER(LTRIM(RTRIM(SubjectName))) = LOWER(LTRIM(RTRIM(@SubjectName))))
    BEGIN
        SELECT -1 AS SubjectId; -- Already exists
        RETURN;
    END

    INSERT INTO Subjects (SubjectName, Description, IsActive, CreatedAt)
    VALUES (LTRIM(RTRIM(@SubjectName)), @Description, @IsActive, GETDATE());

    SELECT SCOPE_IDENTITY() AS SubjectId;
END
GO

-- 10. Update Subject
CREATE OR ALTER PROCEDURE sp_UpdateSubject
    @SubjectId INT,
    @SubjectName NVARCHAR(100),
    @Description NVARCHAR(500) = NULL,
    @IsActive BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM Subjects WHERE LOWER(LTRIM(RTRIM(SubjectName))) = LOWER(LTRIM(RTRIM(@SubjectName))) AND SubjectId <> @SubjectId)
    BEGIN
        SELECT -1 AS Result;
        RETURN;
    END

    UPDATE Subjects
    SET SubjectName = LTRIM(RTRIM(@SubjectName)),
        Description = @Description,
        IsActive = @IsActive
    WHERE SubjectId = @SubjectId;

    SELECT 1 AS Result;
END
GO

-- 11. Delete Subject
CREATE OR ALTER PROCEDURE sp_DeleteSubject
    @SubjectId INT
AS
BEGIN
    SET NOCOUNT ON;

    -- If mapped to batches or courses, deactivate instead of hard delete
    IF EXISTS (SELECT 1 FROM BatchSubjects WHERE SubjectId = @SubjectId)
    BEGIN
        UPDATE Subjects SET IsActive = 0 WHERE SubjectId = @SubjectId;
        SELECT 2 AS Result;
        RETURN;
    END

    DELETE FROM CourseSubjects WHERE SubjectId = @SubjectId;
    DELETE FROM Subjects WHERE SubjectId = @SubjectId;

    SELECT 1 AS Result;
END
GO

-- 12. Get Subjects For Course
CREATE OR ALTER PROCEDURE sp_GetSubjectsByCourseId
    @CourseId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        s.SubjectId,
        s.SubjectName,
        s.Description,
        s.IsActive,
        s.CreatedAt
    FROM Subjects s
    INNER JOIN CourseSubjects cs ON s.SubjectId = cs.SubjectId
    WHERE cs.CourseId = @CourseId
    ORDER BY s.SubjectName ASC;
END
GO

-- 13. Assign Subjects To Course (Comma-delimited string of Subject IDs)
CREATE OR ALTER PROCEDURE sp_AssignSubjectsToCourse
    @CourseId INT,
    @SubjectIds NVARCHAR(MAX) = NULL -- e.g. '1,2,3'
AS
BEGIN
    SET NOCOUNT ON;

    -- Delete existing mappings for this course
    DELETE FROM CourseSubjects WHERE CourseId = @CourseId;

    -- Insert new mappings from CSV
    IF @SubjectIds IS NOT NULL AND LEN(LTRIM(RTRIM(@SubjectIds))) > 0
    BEGIN
        INSERT INTO CourseSubjects (CourseId, SubjectId)
        SELECT @CourseId, CAST(value AS INT)
        FROM STRING_SPLIT(@SubjectIds, ',')
        WHERE ISNUMERIC(value) = 1;
    END

    SELECT 1 AS Result;
END
GO
