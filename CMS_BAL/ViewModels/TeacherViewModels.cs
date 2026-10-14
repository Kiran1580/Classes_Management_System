using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;

namespace CMS_BAL.ViewModels
{
    public class TeacherViewModel
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
        public DateTime CreatedAt { get; set; }
        public int AssignedBatchesCount { get; set; }
    }

    public class TeacherCreateViewModel
    {
        [Display(Name = "Employee Code")]
        public string? EmployeeCode { get; set; }

        [Required(ErrorMessage = "First Name is required.")]
        [StringLength(50, ErrorMessage = "First Name cannot exceed 50 characters.")]
        [Display(Name = "First Name")]
        public string FirstName { get; set; } = string.Empty;

        [Required(ErrorMessage = "Last Name is required.")]
        [StringLength(50, ErrorMessage = "Last Name cannot exceed 50 characters.")]
        [Display(Name = "Last Name")]
        public string LastName { get; set; } = string.Empty;

        [Required(ErrorMessage = "Mobile number is required.")]
        [RegularExpression(@"^[0-9]{10}$", ErrorMessage = "Please enter a valid 10-digit mobile number.")]
        [Display(Name = "Mobile Number")]
        public string Mobile { get; set; } = string.Empty;

        [Required(ErrorMessage = "Email Address is required.")]
        [EmailAddress(ErrorMessage = "Please enter a valid email address.")]
        [StringLength(100, ErrorMessage = "Email cannot exceed 100 characters.")]
        [Display(Name = "Email Address")]
        public string Email { get; set; } = string.Empty;

        [Required(ErrorMessage = "Highest Qualification is required.")]
        [StringLength(100, ErrorMessage = "Qualification cannot exceed 100 characters.")]
        [Display(Name = "Highest Qualification (e.g. M.Sc, M.Ed, B.Tech)")]
        public string Qualification { get; set; } = string.Empty;

        [Required(ErrorMessage = "Joining Date is required.")]
        [DataType(DataType.Date)]
        [Display(Name = "Joining Date")]
        public DateTime JoiningDate { get; set; } = DateTime.Today;

        [Display(Name = "Account Status")]
        public bool IsActive { get; set; } = true;

        [Required(ErrorMessage = "Password is required for teacher login.")]
        [StringLength(100, MinimumLength = 6, ErrorMessage = "Password must be at least 6 characters.")]
        [DataType(DataType.Password)]
        [Display(Name = "Login Password")]
        public string Password { get; set; } = "Teacher@123";

        [Required(ErrorMessage = "Confirm Password is required.")]
        [DataType(DataType.Password)]
        [Compare("Password", ErrorMessage = "Password and Confirm Password do not match.")]
        [Display(Name = "Confirm Password")]
        public string ConfirmPassword { get; set; } = "Teacher@123";

        public string? ProfileImage { get; set; }
    }

    public class TeacherEditViewModel
    {
        public int TeacherId { get; set; }
        public int UserId { get; set; }

        [Display(Name = "Employee Code")]
        public string? EmployeeCode { get; set; }

        [Required(ErrorMessage = "First Name is required.")]
        [StringLength(50, ErrorMessage = "First Name cannot exceed 50 characters.")]
        [Display(Name = "First Name")]
        public string FirstName { get; set; } = string.Empty;

        [Required(ErrorMessage = "Last Name is required.")]
        [StringLength(50, ErrorMessage = "Last Name cannot exceed 50 characters.")]
        [Display(Name = "Last Name")]
        public string LastName { get; set; } = string.Empty;

        [Required(ErrorMessage = "Mobile number is required.")]
        [RegularExpression(@"^[0-9]{10}$", ErrorMessage = "Please enter a valid 10-digit mobile number.")]
        [Display(Name = "Mobile Number")]
        public string Mobile { get; set; } = string.Empty;

        [Required(ErrorMessage = "Email Address is required.")]
        [EmailAddress(ErrorMessage = "Please enter a valid email address.")]
        [StringLength(100, ErrorMessage = "Email cannot exceed 100 characters.")]
        [Display(Name = "Email Address")]
        public string Email { get; set; } = string.Empty;

        [Required(ErrorMessage = "Highest Qualification is required.")]
        [StringLength(100, ErrorMessage = "Qualification cannot exceed 100 characters.")]
        [Display(Name = "Highest Qualification")]
        public string Qualification { get; set; } = string.Empty;

        [Required(ErrorMessage = "Joining Date is required.")]
        [DataType(DataType.Date)]
        [Display(Name = "Joining Date")]
        public DateTime JoiningDate { get; set; } = DateTime.Today;

        [Display(Name = "Account Status")]
        public bool IsActive { get; set; } = true;

        public string? ProfileImage { get; set; }
    }

    public class TeacherBatchViewModel
    {
        public int BatchSubjectId { get; set; }
        public int BatchId { get; set; }
        public string BatchName { get; set; } = string.Empty;
        public int CourseId { get; set; }
        public string CourseName { get; set; } = string.Empty;
        public int SubjectId { get; set; }
        public string SubjectName { get; set; } = string.Empty;
        public string? RoomNo { get; set; }
        public string? StartTime { get; set; }
        public string? EndTime { get; set; }
        public int EnrolledStudentsCount { get; set; }
        public string BatchStatus { get; set; } = "Active";
    }

    public class TeacherDetailsViewModel
    {
        public TeacherViewModel Teacher { get; set; } = new();
        public IEnumerable<TeacherBatchViewModel> AssignedBatches { get; set; } = new List<TeacherBatchViewModel>();
    }

    public class TeacherStatsViewModel
    {
        public int TotalTeachers { get; set; }
        public int ActiveTeachers { get; set; }
        public int InactiveTeachers { get; set; }
        public int AssignedBatches { get; set; }
    }
}
