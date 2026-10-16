SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- ============================================================================
-- 1. Stored Procedure: sp_GetBatchFacultyAssignments
-- Returns all subjects linked to the batch's course or directly to the batch,
-- along with currently assigned Teacher details (if any).
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.sp_GetBatchFacultyAssignments
    @BatchId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET QUOTED_IDENTIFIER ON;

    -- Combine subjects from the Batch's parent Course AND any already present in BatchSubjects
    ;WITH BatchSubjectPool AS (
        SELECT DISTINCT cs.SubjectId
        FROM dbo.Batches b
        INNER JOIN dbo.CourseSubjects cs ON b.CourseId = cs.CourseId
        WHERE b.BatchId = @BatchId

        UNION

        SELECT DISTINCT bs.SubjectId
        FROM dbo.BatchSubjects bs
        WHERE bs.BatchId = @BatchId
    )
    SELECT 
        b.BatchId,
        b.BatchName,
        b.CourseId,
        c.CourseName,
        s.SubjectId,
        s.SubjectName,
        bs.BatchSubjectId,
        bs.TeacherId,
        t.FirstName + ' ' + t.LastName AS TeacherName,
        t.Email AS TeacherEmail,
        t.EmployeeCode
    FROM dbo.Batches b
    CROSS JOIN BatchSubjectPool p
    INNER JOIN dbo.Courses c ON b.CourseId = c.CourseId
    INNER JOIN dbo.Subjects s ON p.SubjectId = s.SubjectId
    LEFT JOIN dbo.BatchSubjects bs ON bs.BatchId = b.BatchId AND bs.SubjectId = s.SubjectId
    LEFT JOIN dbo.Teachers t ON bs.TeacherId = t.TeacherId
    WHERE b.BatchId = @BatchId
    ORDER BY s.SubjectName ASC;
END;
GO

-- ============================================================================
-- 2. Stored Procedure: sp_SaveBatchFacultyAssignment
-- Inserts, updates, or deletes a mapping in BatchSubjects.
-- If @TeacherId IS NULL or <= 0, the mapping is removed (unassigned).
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.sp_SaveBatchFacultyAssignment
    @BatchId INT,
    @SubjectId INT,
    @TeacherId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET QUOTED_IDENTIFIER ON;

    IF @TeacherId IS NULL OR @TeacherId <= 0
    BEGIN
        -- Remove teacher assignment for this batch subject
        DELETE FROM dbo.BatchSubjects 
        WHERE BatchId = @BatchId AND SubjectId = @SubjectId;
    END
    ELSE
    BEGIN
        IF EXISTS (SELECT 1 FROM dbo.BatchSubjects WHERE BatchId = @BatchId AND SubjectId = @SubjectId)
        BEGIN
            UPDATE dbo.BatchSubjects
            SET TeacherId = @TeacherId
            WHERE BatchId = @BatchId AND SubjectId = @SubjectId;
        END
        ELSE
        BEGIN
            INSERT INTO dbo.BatchSubjects (BatchId, SubjectId, TeacherId)
            VALUES (@BatchId, @SubjectId, @TeacherId);
        END
    END
END;
GO
