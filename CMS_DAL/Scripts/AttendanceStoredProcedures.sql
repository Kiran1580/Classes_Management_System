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
        @TotalPresent = ISNULL(SUM(CASE WHEN a.Status = 'Present' THEN 1 ELSE 0 END), 0),
        @TotalAbsent = ISNULL(SUM(CASE WHEN a.Status = 'Absent' THEN 1 ELSE 0 END), 0),
        @TotalLate = ISNULL(SUM(CASE WHEN a.Status IN ('Late', 'Excused') THEN 1 ELSE 0 END), 0)
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
        @AttendedClasses = ISNULL(SUM(CASE WHEN a.Status IN ('Present', 'Late') THEN 1 ELSE 0 END), 0),
        @AbsentClasses = ISNULL(SUM(CASE WHEN a.Status = 'Absent' THEN 1 ELSE 0 END), 0),
        @LateClasses = ISNULL(SUM(CASE WHEN a.Status = 'Late' THEN 1 ELSE 0 END), 0)
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
        @SessionsToday = ISNULL(COUNT(DISTINCT cs.SessionId), 0),
        @TotalMarkedToday = ISNULL(COUNT(a.AttendanceId), 0),
        @PresentToday = ISNULL(SUM(CASE WHEN a.Status = 'Present' THEN 1 ELSE 0 END), 0),
        @AbsentToday = ISNULL(SUM(CASE WHEN a.Status = 'Absent' THEN 1 ELSE 0 END), 0),
        @LateToday = ISNULL(SUM(CASE WHEN a.Status IN ('Late', 'Excused') THEN 1 ELSE 0 END), 0)
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
