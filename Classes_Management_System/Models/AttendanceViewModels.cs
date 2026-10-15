using System;
using System.Collections.Generic;
using CMS_DAL.Models;

namespace Classes_Management_System.Models
{
    public class AttendanceBatchOption
    {
        public int BatchId { get; set; }
        public string BatchName { get; set; } = string.Empty;
    }

    public class AttendanceCourseOption
    {
        public int CourseId { get; set; }
        public string CourseName { get; set; } = string.Empty;
    }

    public class AttendanceIndexViewModel
    {
        public IEnumerable<AttendanceGridItem> Records { get; set; } = new List<AttendanceGridItem>();
        public AttendanceDashboardStats Stats { get; set; } = new AttendanceDashboardStats();
        public IEnumerable<AttendanceBatchOption> Batches { get; set; } = new List<AttendanceBatchOption>();
        public IEnumerable<AttendanceCourseOption> Courses { get; set; } = new List<AttendanceCourseOption>();

        // Filters
        public string? SearchTerm { get; set; }
        public int? BatchId { get; set; }
        public int? CourseId { get; set; }
        public DateTime? FromDate { get; set; }
        public DateTime? ToDate { get; set; }
        public string? Status { get; set; }

        // Pagination & Sorting
        public int PageNumber { get; set; } = 1;
        public int PageSize { get; set; } = 10;
        public int TotalCount { get; set; }
        public int TotalPresent { get; set; }
        public int TotalAbsent { get; set; }
        public int TotalLate { get; set; }
        public string SortColumn { get; set; } = "SessionDate";
        public string SortDirection { get; set; } = "DESC";

        public int TotalPages => (int)Math.Ceiling((double)TotalCount / PageSize);
        public bool HasPreviousPage => PageNumber > 1;
        public bool HasNextPage => PageNumber < TotalPages;
    }

    public class MarkAttendanceViewModel
    {
        public int? SelectedBatchId { get; set; }
        public DateTime SelectedDate { get; set; } = DateTime.Today;
        public int? SelectedSubjectId { get; set; }
        public string? Topic { get; set; }

        public IEnumerable<AttendanceBatchOption> AvailableBatches { get; set; } = new List<AttendanceBatchOption>();
        public IEnumerable<AttendanceStudentItem> Students { get; set; } = new List<AttendanceStudentItem>();

        public bool IsTeacher { get; set; }
        public int? TeacherId { get; set; }
        public string? TeacherName { get; set; }
    }

    public class StudentAttendanceViewModel
    {
        public int StudentId { get; set; }
        public string StudentName { get; set; } = string.Empty;
        public string AdmissionNo { get; set; } = string.Empty;
        public string? ProfileImage { get; set; }

        public int TotalClasses { get; set; }
        public int AttendedClasses { get; set; }
        public int AbsentClasses { get; set; }
        public int LateClasses { get; set; }
        public decimal AttendancePercentage { get; set; }

        public IEnumerable<StudentAttendanceGridItem> Records { get; set; } = new List<StudentAttendanceGridItem>();

        // Filters & Pagination
        public DateTime? FromDate { get; set; }
        public DateTime? ToDate { get; set; }
        public string? Status { get; set; }
        public int PageNumber { get; set; } = 1;
        public int PageSize { get; set; } = 10;
        public int TotalCount { get; set; }
        public string SortColumn { get; set; } = "SessionDate";
        public string SortDirection { get; set; } = "DESC";

        public int TotalPages => (int)Math.Ceiling((double)TotalCount / PageSize);
        public bool HasPreviousPage => PageNumber > 1;
        public bool HasNextPage => PageNumber < TotalPages;

        public bool IsEligible => AttendancePercentage >= 75.00m;
    }
}
