using System;
using System.ComponentModel.DataAnnotations;

namespace CMS_BAL.ViewModels
{
    public class SubjectViewModel
    {
        public int SubjectId { get; set; }

        [Required(ErrorMessage = "Subject Name is required.")]
        [StringLength(100, ErrorMessage = "Subject Name cannot exceed 100 characters.")]
        [Display(Name = "Subject Name")]
        public string SubjectName { get; set; } = string.Empty;

        [StringLength(500, ErrorMessage = "Description cannot exceed 500 characters.")]
        [Display(Name = "Description")]
        public string? Description { get; set; }

        [Display(Name = "Active Status")]
        public bool IsActive { get; set; }

        public DateTime CreatedAt { get; set; }
        public int CoursesCount { get; set; }
    }
}
