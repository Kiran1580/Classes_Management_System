using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;

namespace CMS_BAL.ViewModels
{
    public class CourseViewModel
    {
        public int CourseId { get; set; }

        [Required(ErrorMessage = "Course Name is required.")]
        [StringLength(100, ErrorMessage = "Course Name cannot exceed 100 characters.")]
        [Display(Name = "Course Name")]
        public string CourseName { get; set; } = string.Empty;

        [StringLength(500, ErrorMessage = "Description cannot exceed 500 characters.")]
        [Display(Name = "Description")]
        public string? Description { get; set; }

        [StringLength(50, ErrorMessage = "Duration cannot exceed 50 characters.")]
        [Display(Name = "Duration")]
        public string? Duration { get; set; }

        [Display(Name = "Active Status")]
        public bool IsActive { get; set; }

        public DateTime CreatedAt { get; set; }
        public int SubjectsCount { get; set; }
        public int BatchesCount { get; set; }

        [Display(Name = "Select Subjects")]
        public List<int> SelectedSubjectIds { get; set; } = new List<int>();

        public List<SubjectViewModel> AssignedSubjects { get; set; } = new List<SubjectViewModel>();
        public List<SubjectViewModel> AvailableSubjects { get; set; } = new List<SubjectViewModel>();
    }
}
