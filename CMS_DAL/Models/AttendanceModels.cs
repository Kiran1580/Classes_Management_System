using System;
using System.Collections.Generic;

namespace CMS_DAL.Models
{
    public class ClassSession
    {
        public int SessionId { get; set; }
        public int BatchId { get; set; }
        public int? SubjectId { get; set; }
        public int? TeacherId { get; set; }
        public DateTime SessionDate { get; set; }
        public TimeSpan? StartTime { get; set; }
        public TimeSpan? EndTime { get; set; }
        public string? Topic { get; set; }
        public DateTime CreatedAt { get; set; }
    }

    public class AttendanceStudentItem
    {
        public int StudentId { get; set; }
        public string AdmissionNo { get; set; } = string.Empty;
        public string FullName { get; set; } = string.Empty;
        public string? Mobile { get; set; }
        public string? Email { get; set; }
        public string? ProfileImage { get; set; }
        public string Status { get; set; } = "Present"; // Present, Absent, Late, Excused
        public string? Remarks { get; set; }
        public int? SessionId { get; set; }
        public string? Topic { get; set; }
        public int? TeacherId { get; set; }
        public bool IsAlreadyMarked { get; set; }
    }

    public class AttendanceGridItem
    {
        public int AttendanceId { get; set; }
        public int SessionId { get; set; }
        public DateTime SessionDate { get; set; }
        public string? Topic { get; set; }
        public int BatchId { get; set; }
        public string BatchName { get; set; } = string.Empty;
        public string CourseName { get; set; } = string.Empty;
        public string SubjectName { get; set; } = string.Empty;
        public string TeacherName { get; set; } = string.Empty;
        public int StudentId { get; set; }
        public string AdmissionNo { get; set; } = string.Empty;
        public string StudentName { get; set; } = string.Empty;
        public string? ProfileImage { get; set; }
        public string Status { get; set; } = "Present";
        public string? Remarks { get; set; }
        public DateTime MarkedAt { get; set; }
    }

    public class StudentAttendanceGridItem
    {
        public int AttendanceId { get; set; }
        public int SessionId { get; set; }
        public DateTime SessionDate { get; set; }
        public string? Topic { get; set; }
        public string BatchName { get; set; } = string.Empty;
        public string SubjectName { get; set; } = string.Empty;
        public string TeacherName { get; set; } = string.Empty;
        public string Status { get; set; } = "Present";
        public string? Remarks { get; set; }
        public DateTime MarkedAt { get; set; }
    }

    public class AttendanceDashboardStats
    {
        public DateTime TodayDate { get; set; }
        public int SessionsToday { get; set; }
        public int TotalMarkedToday { get; set; }
        public int PresentToday { get; set; }
        public int AbsentToday { get; set; }
        public int LateToday { get; set; }
        public decimal OverallRate { get; set; }
    }

    public class SaveAttendanceItemInput
    {
        public int StudentId { get; set; }
        public string Status { get; set; } = "Present";
        public string? Remarks { get; set; }
    }

    public class SaveBatchAttendanceRequest
    {
        public int BatchId { get; set; }
        public int? SubjectId { get; set; }
        public int? TeacherId { get; set; }
        public DateTime SessionDate { get; set; }
        public string? Topic { get; set; }
        public List<SaveAttendanceItemInput> Students { get; set; } = new List<SaveAttendanceItemInput>();
    }
}
