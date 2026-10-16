using System;
using System.Collections.Generic;

namespace CMS_BAL.ViewModels
{
    public class StudentCoursesAndBatchesViewModel
    {
        // Student Info
        public int StudentId { get; set; }
        public int? UserId { get; set; }
        public string AdmissionNo { get; set; } = string.Empty;
        public string StudentFullName { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string? Mobile { get; set; }
        public DateTime? AdmissionDate { get; set; }
        public bool IsActive { get; set; }

        // Enrolled Batches with their Course and Subject details
        public List<StudentEnrolledBatchItem> Batches { get; set; } = new();

        // Convenience Helpers
        public bool HasBatches => Batches != null && Batches.Count > 0;
        public int ActiveBatchesCount => Batches?.FindAll(b => string.Equals(b.BatchStatus, "Active", StringComparison.OrdinalIgnoreCase)).Count ?? 0;
    }

    public class StudentEnrolledBatchItem
    {
        public int EnrollmentId { get; set; }
        public int StudentId { get; set; }
        public int BatchId { get; set; }
        public string BatchName { get; set; } = string.Empty;
        public string BatchStatus { get; set; } = "Active";
        public DateTime? BatchStartDate { get; set; }
        public DateTime? BatchEndDate { get; set; }
        public string? StartTimeStr { get; set; }
        public string? EndTimeStr { get; set; }
        public string? RoomNo { get; set; }
        public int Capacity { get; set; }
        public int EnrolledCount { get; set; }

        public DateTime EnrollmentDate { get; set; }
        public DateTime? EnrollmentStartDate { get; set; }
        public DateTime? EnrollmentEndDate { get; set; }
        public string EnrollmentStatus { get; set; } = "Active";

        // Course Info
        public int CourseId { get; set; }
        public string CourseName { get; set; } = string.Empty;
        public string? CourseDescription { get; set; }
        public string? CourseDuration { get; set; }
        public string? AcademicYearName { get; set; }

        // Attendance stats in this batch
        public int TotalSessions { get; set; }
        public int AttendedSessions { get; set; }
        public decimal AttendancePercentage => TotalSessions > 0 
            ? Math.Round(((decimal)AttendedSessions / TotalSessions) * 100m, 1) 
            : 100.0m;

        // Subjects and Teachers in this batch
        public List<StudentBatchSubjectItem> Subjects { get; set; } = new();
    }

    public class StudentBatchSubjectItem
    {
        public int BatchId { get; set; }
        public int SubjectId { get; set; }
        public string SubjectName { get; set; } = string.Empty;
        public string? SubjectDescription { get; set; }
        public int? TeacherId { get; set; }
        public string TeacherName { get; set; } = "Faculty Not Assigned";
        public string? TeacherQualification { get; set; }
        public string? TeacherEmail { get; set; }
        public string? TeacherMobile { get; set; }
    }
}
