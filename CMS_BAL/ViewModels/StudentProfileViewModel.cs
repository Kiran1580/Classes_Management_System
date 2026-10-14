using System;
using System.ComponentModel.DataAnnotations;

namespace CMS_BAL.ViewModels
{
    public class StudentProfileViewModel
    {
        public int StudentId { get; set; }
        public int? UserId { get; set; }

        public string AdmissionNo { get; set; } = string.Empty;
        public string FirstName { get; set; } = string.Empty;
        public string LastName { get; set; } = string.Empty;
        public string FullName => $"{FirstName} {LastName}".Trim();

        public string? Email { get; set; }
        public string? Mobile { get; set; }
        public string? ParentName { get; set; }
        public string? ParentMobile { get; set; }

        public string? CourseName { get; set; }
        public string? BatchName { get; set; }
        public DateTime AdmissionDate { get; set; }

        [Required(ErrorMessage = "Please select gender")]
        public string? Gender { get; set; }

        [Required(ErrorMessage = "Please provide your date of birth")]
        [DataType(DataType.Date)]
        [Display(Name = "Date of Birth")]
        public DateTime? DateOfBirth { get; set; }

        [Required(ErrorMessage = "Please provide your residential address")]
        [StringLength(500, ErrorMessage = "Address cannot exceed 500 characters")]
        public string? Address { get; set; }

        public string? ProfileImage { get; set; }

        public bool IsProfileComplete =>
            !string.IsNullOrWhiteSpace(Gender) &&
            DateOfBirth.HasValue &&
            !string.IsNullOrWhiteSpace(Address);
    }
}
