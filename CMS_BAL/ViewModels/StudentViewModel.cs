using System;
using System.ComponentModel.DataAnnotations;

namespace CMS_BAL.ViewModels
{
    public class StudentViewModel
    {
        public int StudentId { get; set; }
        public int? UserId { get; set; }

        [Display(Name = "Admission No")]
        public string AdmissionNo { get; set; } = string.Empty;

        [Display(Name = "First Name")]
        public string FirstName { get; set; } = string.Empty;

        [Display(Name = "Last Name")]
        public string LastName { get; set; } = string.Empty;

        [Display(Name = "Full Name")]
        public string FullName { get; set; } = string.Empty;

        public string? Gender { get; set; }

        [Display(Name = "Date of Birth")]
        public DateTime? DateOfBirth { get; set; }

        public string? Mobile { get; set; }
        public string? Email { get; set; }
        public string? Address { get; set; }

        [Display(Name = "Parent / Guardian")]
        public string? ParentName { get; set; }

        [Display(Name = "Parent Mobile")]
        public string? ParentMobile { get; set; }

        [Display(Name = "Admission Date")]
        public DateTime AdmissionDate { get; set; }

        [Display(Name = "Profile Photo")]
        public string? ProfileImage { get; set; }

        public bool IsActive { get; set; } = true;
        public DateTime CreatedAt { get; set; }

        // Associated Batch / Course
        public int? EnrollmentId { get; set; }
        public int? BatchId { get; set; }
        public string? BatchName { get; set; }
        public int? CourseId { get; set; }
        public string? CourseName { get; set; }
        public string? EnrollmentStatus { get; set; }
    }

    public class StudentStatsViewModel
    {
        public int TotalStudents { get; set; }
        public int ActiveStudents { get; set; }
        public int InactiveStudents { get; set; }
        public int EnrolledStudents { get; set; }
        public int NewAdmissionsThisMonth { get; set; }
    }
}
