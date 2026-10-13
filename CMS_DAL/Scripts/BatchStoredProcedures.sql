USE ClassesManagementDb;
GO

-- ==========================================================
-- 1. Get Paged Batches with Search, Filter, Sort, Pagination
-- ==========================================================
CREATE OR ALTER PROCEDURE sp_GetPagedBatches
    @SearchTerm     NVARCHAR(100) = NULL,
    @PageNumber     INT           = 1,
    @PageSize       INT           = 6,
    @SortColumn     NVARCHAR(50)  = 'BatchId',
    @SortDirection  NVARCHAR(10)  = 'DESC',
    @CourseFilter   INT           = NULL,
    @StatusFilter   NVARCHAR(20)  = NULL,
    @TotalCount     INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @SearchTerm = LTRIM(RTRIM(@SearchTerm));
    IF @SearchTerm = '' SET @SearchTerm = NULL;

    IF @PageNumber < 1 SET @PageNumber = 1;
    IF @PageSize < 1   SET @PageSize = 6;

    IF @SortColumn IS NULL OR @SortColumn = '' SET @SortColumn = 'BatchId';
    IF @SortDirection IS NULL OR @SortDirection = '' SET @SortDirection = 'DESC';
    SET @SortDirection = UPPER(@SortDirection);
    IF @SortDirection NOT IN ('ASC', 'DESC') SET @SortDirection = 'DESC';

    -- Count total matching rows
    SELECT @TotalCount = COUNT(1)
    FROM Batches b
    INNER JOIN Courses c ON b.CourseId = c.CourseId
    WHERE
        (@SearchTerm IS NULL OR
         b.BatchName LIKE '%' + @SearchTerm + '%' OR
         c.CourseName LIKE '%' + @SearchTerm + '%' OR
         b.RoomNo LIKE '%' + @SearchTerm + '%')
        AND (@CourseFilter IS NULL OR b.CourseId = @CourseFilter)
        AND (@StatusFilter IS NULL OR b.Status = @StatusFilter);

    -- Paged records
    SELECT
        b.BatchId,
        b.CourseId,
        b.AcademicYearId,
        b.BatchName,
        b.StartDate,
        b.EndDate,
        b.StartTime,
        b.EndTime,
        b.Capacity,
        b.RoomNo,
        b.Status,
        b.CreatedAt,
        c.CourseName,
        ay.YearName AS AcademicYearName,
        (SELECT COUNT(1) FROM Enrollments e WHERE e.BatchId = b.BatchId AND e.Status = 'Active') AS EnrolledCount
    FROM Batches b
    INNER JOIN Courses c ON b.CourseId = c.CourseId
    INNER JOIN AcademicYears ay ON b.AcademicYearId = ay.AcademicYearId
    WHERE
        (@SearchTerm IS NULL OR
         b.BatchName LIKE '%' + @SearchTerm + '%' OR
         c.CourseName LIKE '%' + @SearchTerm + '%' OR
         b.RoomNo LIKE '%' + @SearchTerm + '%')
        AND (@CourseFilter IS NULL OR b.CourseId = @CourseFilter)
        AND (@StatusFilter IS NULL OR b.Status = @StatusFilter)
    ORDER BY
        CASE WHEN @SortColumn = 'BatchName' AND @SortDirection = 'ASC'  THEN b.BatchName END ASC,
        CASE WHEN @SortColumn = 'BatchName' AND @SortDirection = 'DESC' THEN b.BatchName END DESC,
        CASE WHEN @SortColumn = 'CourseName' AND @SortDirection = 'ASC'  THEN c.CourseName END ASC,
        CASE WHEN @SortColumn = 'CourseName' AND @SortDirection = 'DESC' THEN c.CourseName END DESC,
        CASE WHEN @SortColumn = 'StartDate' AND @SortDirection = 'ASC'  THEN b.StartDate END ASC,
        CASE WHEN @SortColumn = 'StartDate' AND @SortDirection = 'DESC' THEN b.StartDate END DESC,
        CASE WHEN @SortColumn = 'Capacity'  AND @SortDirection = 'ASC'  THEN b.Capacity END ASC,
        CASE WHEN @SortColumn = 'Capacity'  AND @SortDirection = 'DESC' THEN b.Capacity END DESC,
        CASE WHEN @SortColumn = 'Status'    AND @SortDirection = 'ASC'  THEN b.Status END ASC,
        CASE WHEN @SortColumn = 'Status'    AND @SortDirection = 'DESC' THEN b.Status END DESC,
        CASE WHEN @SortColumn = 'CreatedAt' AND @SortDirection = 'ASC'  THEN b.CreatedAt END ASC,
        CASE WHEN @SortColumn = 'CreatedAt' AND @SortDirection = 'DESC' THEN b.CreatedAt END DESC,
        CASE WHEN @SortColumn = 'BatchId'   AND @SortDirection = 'ASC'  THEN b.BatchId END ASC,
        CASE WHEN @SortColumn = 'BatchId'   AND @SortDirection = 'DESC' THEN b.BatchId END DESC,
        b.BatchId DESC
    OFFSET (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END;
GO

-- ==========================================================
-- 2. Get All Batches
-- ==========================================================
CREATE OR ALTER PROCEDURE sp_GetAllBatches
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        b.BatchId, b.CourseId, b.AcademicYearId, b.BatchName,
        b.StartDate, b.EndDate, b.StartTime, b.EndTime,
        b.Capacity, b.RoomNo, b.Status, b.CreatedAt,
        c.CourseName,
        ay.YearName AS AcademicYearName,
        (SELECT COUNT(1) FROM Enrollments e WHERE e.BatchId = b.BatchId AND e.Status = 'Active') AS EnrolledCount
    FROM Batches b
    INNER JOIN Courses c ON b.CourseId = c.CourseId
    INNER JOIN AcademicYears ay ON b.AcademicYearId = ay.AcademicYearId
    ORDER BY b.BatchId DESC;
END;
GO

-- ==========================================================
-- 3. Get Batch By Id
-- ==========================================================
CREATE OR ALTER PROCEDURE sp_GetBatchById
    @BatchId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        b.BatchId, b.CourseId, b.AcademicYearId, b.BatchName,
        b.StartDate, b.EndDate, b.StartTime, b.EndTime,
        b.Capacity, b.RoomNo, b.Status, b.CreatedAt,
        c.CourseName,
        ay.YearName AS AcademicYearName,
        (SELECT COUNT(1) FROM Enrollments e WHERE e.BatchId = b.BatchId AND e.Status = 'Active') AS EnrolledCount
    FROM Batches b
    INNER JOIN Courses c ON b.CourseId = c.CourseId
    INNER JOIN AcademicYears ay ON b.AcademicYearId = ay.AcademicYearId
    WHERE b.BatchId = @BatchId;
END;
GO

-- ==========================================================
-- 4. Create Batch
-- Returns: new BatchId, -1 if duplicate name in same course+year
-- ==========================================================
CREATE OR ALTER PROCEDURE sp_CreateBatch
    @CourseId       INT,
    @AcademicYearId INT,
    @BatchName      NVARCHAR(100),
    @StartDate      DATE          = NULL,
    @EndDate        DATE          = NULL,
    @StartTime      TIME          = NULL,
    @EndTime        TIME          = NULL,
    @Capacity       INT           = 50,
    @RoomNo         NVARCHAR(50)  = NULL,
    @Status         NVARCHAR(20)  = 'Active'
AS
BEGIN
    SET NOCOUNT ON;

    -- Duplicate check: same batch name in same course + academic year
    IF EXISTS (
        SELECT 1 FROM Batches
        WHERE BatchName = @BatchName AND CourseId = @CourseId AND AcademicYearId = @AcademicYearId
    )
    BEGIN
        SELECT -1 AS BatchId;
        RETURN;
    END

    INSERT INTO Batches (CourseId, AcademicYearId, BatchName, StartDate, EndDate, StartTime, EndTime, Capacity, RoomNo, Status)
    VALUES (@CourseId, @AcademicYearId, @BatchName, @StartDate, @EndDate, @StartTime, @EndTime, @Capacity, @RoomNo, @Status);

    SELECT CAST(SCOPE_IDENTITY() AS INT) AS BatchId;
END;
GO

-- ==========================================================
-- 5. Update Batch
-- Returns: 1 success, -1 duplicate, 0 fail
-- ==========================================================
CREATE OR ALTER PROCEDURE sp_UpdateBatch
    @BatchId        INT,
    @CourseId       INT,
    @AcademicYearId INT,
    @BatchName      NVARCHAR(100),
    @StartDate      DATE          = NULL,
    @EndDate        DATE          = NULL,
    @StartTime      TIME          = NULL,
    @EndTime        TIME          = NULL,
    @Capacity       INT           = 50,
    @RoomNo         NVARCHAR(50)  = NULL,
    @Status         NVARCHAR(20)  = 'Active'
AS
BEGIN
    SET NOCOUNT ON;

    -- Duplicate check: same name in same course+year but different batch
    IF EXISTS (
        SELECT 1 FROM Batches
        WHERE BatchName = @BatchName AND CourseId = @CourseId AND AcademicYearId = @AcademicYearId AND BatchId <> @BatchId
    )
    BEGIN
        SELECT -1;
        RETURN;
    END

    UPDATE Batches SET
        CourseId       = @CourseId,
        AcademicYearId = @AcademicYearId,
        BatchName      = @BatchName,
        StartDate      = @StartDate,
        EndDate        = @EndDate,
        StartTime      = @StartTime,
        EndTime        = @EndTime,
        Capacity       = @Capacity,
        RoomNo         = @RoomNo,
        Status         = @Status
    WHERE BatchId = @BatchId;

    SELECT CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END;
END;
GO

-- ==========================================================
-- 6. Delete Batch
-- Returns: 1 deleted, 2 deactivated (has enrollments), 0 fail
-- ==========================================================
CREATE OR ALTER PROCEDURE sp_DeleteBatch
    @BatchId INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Check if batch has active enrollments
    IF EXISTS (SELECT 1 FROM Enrollments WHERE BatchId = @BatchId)
    BEGIN
        UPDATE Batches SET Status = 'Inactive' WHERE BatchId = @BatchId;
        SELECT 2;
        RETURN;
    END

    DELETE FROM BatchSubjects WHERE BatchId = @BatchId;
    DELETE FROM Batches WHERE BatchId = @BatchId;
    SELECT CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END;
END;
GO

-- ==========================================================
-- 7. Get Batch Stats
-- ==========================================================
CREATE OR ALTER PROCEDURE sp_GetBatchStats
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        COUNT(1) AS TotalBatches,
        SUM(CASE WHEN Status = 'Active' THEN 1 ELSE 0 END) AS ActiveBatches,
        SUM(CASE WHEN Status = 'Inactive' THEN 1 ELSE 0 END) AS InactiveBatches,
        (SELECT COUNT(1) FROM Enrollments WHERE Status = 'Active') AS TotalEnrolled,
        (SELECT COUNT(DISTINCT CourseId) FROM Batches WHERE Status = 'Active') AS CoursesWithBatches
    FROM Batches;
END;
GO
