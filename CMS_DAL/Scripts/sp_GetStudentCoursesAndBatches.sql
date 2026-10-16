SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- ==============================================================================
-- Stored Procedure: sp_GetStudentCoursesAndBatches
-- Description: Retrieves enrolled courses, batches, schedule timings, classroom,
--              fellow batchmates count, subject syllabus, assigned faculty staff,
--              and per-batch attendance for a student (by UserId or StudentId).
-- ==============================================================================
CREATE OR ALTER PROCEDURE dbo.sp_GetStudentCoursesAndBatches
    @UserId INT = NULL,
    @StudentId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Resolve StudentId if UserId is supplied
    IF @StudentId IS NULL AND @UserId IS NOT NULL
    BEGIN
        SELECT TOP 1 @StudentId = StudentId 
        FROM dbo.Students 
        WHERE UserId = @UserId;
    END

    -- 1. Student Basic Identity
    SELECT 
        s.StudentId,
        s.UserId,
        s.AdmissionNo,
        s.FirstName + ' ' + ISNULL(s.LastName, '') AS StudentFullName,
        s.Email,
        s.Mobile,
        s.AdmissionDate,
        s.IsActive
    FROM dbo.Students s
    WHERE s.StudentId = @StudentId;

    -- 2. Enrolled Batches and Associated Courses
    SELECT 
        e.EnrollmentId,
        e.StudentId,
        e.BatchId,
        b.BatchName,
        b.Status AS BatchStatus,
        b.StartDate AS BatchStartDate,
        b.EndDate AS BatchEndDate,
        CONVERT(VARCHAR(5), b.StartTime, 108) AS StartTimeStr,
        CONVERT(VARCHAR(5), b.EndTime, 108) AS EndTimeStr,
        b.RoomNo,
        b.Capacity,
        (SELECT COUNT(1) FROM dbo.Enrollments WHERE BatchId = b.BatchId AND Status = 'Active') AS EnrolledCount,
        e.EnrollmentDate,
        e.StartDate AS EnrollmentStartDate,
        e.EndDate AS EnrollmentEndDate,
        e.Status AS EnrollmentStatus,
        c.CourseId,
        c.CourseName,
        c.Description AS CourseDescription,
        c.Duration AS CourseDuration,
        ISNULL(ay.YearName, 'Current Academic Year') AS AcademicYearName,
        (SELECT COUNT(1) 
         FROM dbo.Attendance a 
         INNER JOIN dbo.ClassSessions cs ON a.SessionId = cs.SessionId 
         WHERE a.StudentId = @StudentId AND cs.BatchId = b.BatchId) AS TotalSessions,
        (SELECT COUNT(1) 
         FROM dbo.Attendance a 
         INNER JOIN dbo.ClassSessions cs ON a.SessionId = cs.SessionId 
         WHERE a.StudentId = @StudentId AND cs.BatchId = b.BatchId AND a.Status = 'Present') AS AttendedSessions
    FROM dbo.Enrollments e
    INNER JOIN dbo.Batches b ON e.BatchId = b.BatchId
    INNER JOIN dbo.Courses c ON b.CourseId = c.CourseId
    LEFT JOIN dbo.AcademicYears ay ON b.AcademicYearId = ay.AcademicYearId
    WHERE e.StudentId = @StudentId
    ORDER BY e.EnrollmentDate DESC;

    -- 3. Subjects and Assigned Faculty Staff for these Batches
    SELECT 
        b.BatchId,
        sub.SubjectId,
        sub.SubjectName,
        sub.Description AS SubjectDescription,
        t.TeacherId,
        ISNULL(t.FirstName + ' ' + ISNULL(t.LastName, ''), 'Faculty Not Assigned') AS TeacherName,
        t.Qualification AS TeacherQualification,
        t.Email AS TeacherEmail,
        t.Mobile AS TeacherMobile
    FROM dbo.Enrollments e
    INNER JOIN dbo.Batches b ON e.BatchId = b.BatchId
    INNER JOIN (
        SELECT bs.BatchId, bs.SubjectId, bs.TeacherId 
        FROM dbo.BatchSubjects bs
        UNION
        SELECT b2.BatchId, cs.SubjectId, NULL AS TeacherId
        FROM dbo.CourseSubjects cs
        INNER JOIN dbo.Batches b2 ON cs.CourseId = b2.CourseId
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.BatchSubjects bs2 
            WHERE bs2.BatchId = b2.BatchId AND bs2.SubjectId = cs.SubjectId
        )
    ) batch_sub ON b.BatchId = batch_sub.BatchId
    INNER JOIN dbo.Subjects sub ON batch_sub.SubjectId = sub.SubjectId
    LEFT JOIN dbo.Teachers t ON batch_sub.TeacherId = t.TeacherId
    WHERE e.StudentId = @StudentId
    ORDER BY b.BatchId, sub.SubjectName;
END
GO
