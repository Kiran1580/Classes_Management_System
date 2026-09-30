USE ClassesManagementDb;
GO

-- ==========================================================
-- 1. Get Paged Courses with Search, Sorting, and Pagination
-- ==========================================================
CREATE OR ALTER PROCEDURE sp_GetPagedCourses
    @SearchTerm NVARCHAR(100) = NULL,
    @PageNumber INT = 1,
    @PageSize INT = 6,
    @SortColumn NVARCHAR(50) = 'Id',
    @SortDirection NVARCHAR(10) = 'DESC',
    @TotalCount INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @SearchTerm = LTRIM(RTRIM(@SearchTerm));
    IF @SearchTerm = '' SET @SearchTerm = NULL;

    IF @SortColumn IS NULL OR @SortColumn = '' SET @SortColumn = 'Id';
    IF @SortDirection IS NULL OR @SortDirection = '' SET @SortDirection = 'DESC';
    SET @SortDirection = UPPER(@SortDirection);
    IF @SortDirection NOT IN ('ASC', 'DESC') SET @SortDirection = 'DESC';

    -- Calculate total matching records
    SELECT @TotalCount = COUNT(1)
    FROM Courses c
    WHERE (@SearchTerm IS NULL 
           OR c.CourseName LIKE '%' + @SearchTerm + '%' 
           OR c.Description LIKE '%' + @SearchTerm + '%'
           OR c.Duration LIKE '%' + @SearchTerm + '%');

    -- Fetch paged and sorted rows
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
    WHERE (@SearchTerm IS NULL 
           OR c.CourseName LIKE '%' + @SearchTerm + '%' 
           OR c.Description LIKE '%' + @SearchTerm + '%'
           OR c.Duration LIKE '%' + @SearchTerm + '%')
    ORDER BY 
        CASE WHEN @SortColumn = 'Name' AND @SortDirection = 'ASC' THEN c.CourseName END ASC,
        CASE WHEN @SortColumn = 'Name' AND @SortDirection = 'DESC' THEN c.CourseName END DESC,
        CASE WHEN @SortColumn = 'Duration' AND @SortDirection = 'ASC' THEN c.Duration END ASC,
        CASE WHEN @SortColumn = 'Duration' AND @SortDirection = 'DESC' THEN c.Duration END DESC,
        CASE WHEN @SortColumn = 'CreatedAt' AND @SortDirection = 'ASC' THEN c.CreatedAt END ASC,
        CASE WHEN @SortColumn = 'CreatedAt' AND @SortDirection = 'DESC' THEN c.CreatedAt END DESC,
        CASE WHEN @SortColumn = 'Id' AND @SortDirection = 'ASC' THEN c.CourseId END ASC,
        CASE WHEN @SortColumn = 'Id' AND @SortDirection = 'DESC' THEN c.CourseId END DESC,
        c.CourseId DESC
    OFFSET (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- ==========================================================
-- 2. Get Paged Subjects with Search, Sorting, and Pagination
-- ==========================================================
CREATE OR ALTER PROCEDURE sp_GetPagedSubjects
    @SearchTerm NVARCHAR(100) = NULL,
    @PageNumber INT = 1,
    @PageSize INT = 6,
    @SortColumn NVARCHAR(50) = 'Id',
    @SortDirection NVARCHAR(10) = 'DESC',
    @TotalCount INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @SearchTerm = LTRIM(RTRIM(@SearchTerm));
    IF @SearchTerm = '' SET @SearchTerm = NULL;

    IF @SortColumn IS NULL OR @SortColumn = '' SET @SortColumn = 'Id';
    IF @SortDirection IS NULL OR @SortDirection = '' SET @SortDirection = 'DESC';
    SET @SortDirection = UPPER(@SortDirection);
    IF @SortDirection NOT IN ('ASC', 'DESC') SET @SortDirection = 'DESC';

    -- Calculate total matching records
    SELECT @TotalCount = COUNT(1)
    FROM Subjects s
    WHERE (@SearchTerm IS NULL 
           OR s.SubjectName LIKE '%' + @SearchTerm + '%' 
           OR s.Description LIKE '%' + @SearchTerm + '%');

    -- Fetch paged and sorted rows
    SELECT 
        s.SubjectId,
        s.SubjectName,
        s.Description,
        s.IsActive,
        s.CreatedAt,
        (SELECT COUNT(1) FROM CourseSubjects cs WHERE cs.SubjectId = s.SubjectId) AS CoursesCount
    FROM Subjects s
    WHERE (@SearchTerm IS NULL 
           OR s.SubjectName LIKE '%' + @SearchTerm + '%' 
           OR s.Description LIKE '%' + @SearchTerm + '%')
    ORDER BY 
        CASE WHEN @SortColumn = 'Name' AND @SortDirection = 'ASC' THEN s.SubjectName END ASC,
        CASE WHEN @SortColumn = 'Name' AND @SortDirection = 'DESC' THEN s.SubjectName END DESC,
        CASE WHEN @SortColumn = 'CreatedAt' AND @SortDirection = 'ASC' THEN s.CreatedAt END ASC,
        CASE WHEN @SortColumn = 'CreatedAt' AND @SortDirection = 'DESC' THEN s.CreatedAt END DESC,
        CASE WHEN @SortColumn = 'Id' AND @SortDirection = 'ASC' THEN s.SubjectId END ASC,
        CASE WHEN @SortColumn = 'Id' AND @SortDirection = 'DESC' THEN s.SubjectId END DESC,
        s.SubjectId DESC
    OFFSET (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END
GO
