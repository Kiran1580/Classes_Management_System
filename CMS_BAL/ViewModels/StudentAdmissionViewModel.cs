using System;
using System.ComponentModel.DataAnnotations;

namespace CMS_BAL.ViewModels
{
    public class StudentAdmissionViewModel
    {
        public int StudentId { get; set; }

        [Display(Name = "Admission Number")]
        [StringLength(50, ErrorMessage = "Admission Number cannot exceed 50 characters.")]
        public string? AdmissionNo { get; set; }

        [Required(ErrorMessage = "First Name is required.")]
        [StringLength(50, ErrorMessage = "First Name cannot exceed 50 characters.")]
        [Display(Name = "First Name")]
        public string FirstName { get; set; } = string.Empty;

        [Required(ErrorMessage = "Last Name is required.")]
        [StringLength(50, ErrorMessage = "Last Name cannot exceed 50 characters.")]
        [Display(Name = "Last Name")]
        public string LastName { get; set; } = string.Empty;

        [Display(Name = "Gender")]
        public string? Gender { get; set; } = "Male";

        [Display(Name = "Date of Birth")]
        [DataType(DataType.Date)]
        public DateTime? DateOfBirth { get; set; }

        [Required(ErrorMessage = "Student Mobile Number is required.")]
        [RegularExpression(@"^[0-9]{10}$", ErrorMessage = "Please enter a valid 10-digit mobile number.")]
        [Display(Name = "Mobile Number")]
        public string Mobile { get; set; } = string.Empty;

        [EmailAddress(ErrorMessage = "Please enter a valid email address.")]
        [StringLength(100, ErrorMessage = "Email cannot exceed 100 characters.")]
        [Display(Name = "Email Address")]
        public string? Email { get; set; }

        [StringLength(255, ErrorMessage = "Address cannot exceed 255 characters.")]
        [Display(Name = "Residential Address")]
        public string? Address { get; set; }

        [Required(ErrorMessage = "Parent / Guardian Name is required.")]
        [StringLength(100, ErrorMessage = "Parent Name cannot exceed 100 characters.")]
        [Display(Name = "Parent / Guardian Name")]
        public string ParentName { get; set; } = string.Empty;

        [Required(ErrorMessage = "Parent Contact Number is required.")]
        [RegularExpression(@"^[0-9]{10}$", ErrorMessage = "Please enter a valid 10-digit parent contact number.")]
        [Display(Name = "Parent Mobile Number")]
        public string ParentMobile { get; set; } = string.Empty;

        [Required(ErrorMessage = "Admission Date is required.")]
        [DataType(DataType.Date)]
        [Display(Name = "Admission Date")]
        public DateTime AdmissionDate { get; set; } = DateTime.Today;

        [Display(Name = "Profile Photo Path")]
        public string? ProfileImage { get; set; }

        public bool IsActive { get; set; } = true;

        // Academic Allocation
        [Display(Name = "Selected Course")]
        public int? CourseId { get; set; }

        [Display(Name = "Assigned Batch")]
        public int? BatchId { get; set; }
    }
}
