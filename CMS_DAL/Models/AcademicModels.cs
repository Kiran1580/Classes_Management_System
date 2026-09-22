using System;

namespace CMS_DAL.Models
{
    public class AcademicYear
    {
        public int AcademicYearId { get; set; }
        public string YearName { get; set; } = string.Empty;
        public DateTime StartDate { get; set; }
        public DateTime EndDate { get; set; }
        public bool IsCurrent { get; set; }
        public DateTime CreatedAt { get; set; }
    }

    public class Course
    {
        public int CourseId { get; set; }
        public string CourseName { get; set; } = string.Empty;
        public string? Description { get; set; }
        public string? Duration { get; set; }
        public bool IsActive { get; set; } = true;
        public DateTime CreatedAt { get; set; }
    }

    public class Subject
    {
        public int SubjectId { get; set; }
        public string SubjectName { get; set; } = string.Empty;
        public string? Description { get; set; }
        public bool IsActive { get; set; } = true;
        public DateTime CreatedAt { get; set; }
    }

    public class Batch
    {
        public int BatchId { get; set; }
        public int CourseId { get; set; }
        public string CourseName { get; set; } = string.Empty;
        public int AcademicYearId { get; set; }
        public string AcademicYearName { get; set; } = string.Empty;
        public string BatchName { get; set; } = string.Empty;
        public DateTime? StartDate { get; set; }
        public DateTime? EndDate { get; set; }
        public TimeSpan? StartTime { get; set; }
        public TimeSpan? EndTime { get; set; }
        public int Capacity { get; set; } = 50;
        public string? RoomNo { get; set; }
        public string Status { get; set; } = "Active";
        public DateTime CreatedAt { get; set; }
    }

    public class Teacher
    {
        public int TeacherId { get; set; }
        public int UserId { get; set; }
        public string? EmployeeCode { get; set; }
        public string FirstName { get; set; } = string.Empty;
        public string LastName { get; set; } = string.Empty;
        public string FullName => $"{FirstName} {LastName}".Trim();
        public string? Mobile { get; set; }
        public string? Email { get; set; }
        public string? Qualification { get; set; }
        public DateTime? JoiningDate { get; set; }
        public string? ProfileImage { get; set; }
        public bool IsActive { get; set; } = true;
    }

    public class Student
    {
        public int StudentId { get; set; }
        public int UserId { get; set; }
        public string AdmissionNo { get; set; } = string.Empty;
        public string FirstName { get; set; } = string.Empty;
        public string LastName { get; set; } = string.Empty;
        public string FullName => $"{FirstName} {LastName}".Trim();
        public string? Gender { get; set; }
        public DateTime? DateOfBirth { get; set; }
        public string? Mobile { get; set; }
        public string? Email { get; set; }
        public string? Address { get; set; }
        public string? ParentName { get; set; }
        public string? ParentMobile { get; set; }
        public DateTime AdmissionDate { get; set; }
        public string? ProfileImage { get; set; }
        public bool IsActive { get; set; } = true;
    }
}
