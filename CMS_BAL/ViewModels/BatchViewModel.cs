using System;
using System.ComponentModel.DataAnnotations;

namespace CMS_BAL.ViewModels
{
    public class BatchViewModel
    {
        public int BatchId { get; set; }

        [Required(ErrorMessage = "Course is required.")]
        [Display(Name = "Course")]
        public int CourseId { get; set; }

        [Required(ErrorMessage = "Academic Year is required.")]
        [Display(Name = "Academic Year")]
        public int AcademicYearId { get; set; }

        [Required(ErrorMessage = "Batch Name is required.")]
        [StringLength(100, ErrorMessage = "Batch Name cannot exceed 100 characters.")]
        [Display(Name = "Batch Name")]
        public string BatchName { get; set; } = string.Empty;

        [Display(Name = "Start Date")]
        public DateTime? StartDate { get; set; }

        [Display(Name = "End Date")]
        public DateTime? EndDate { get; set; }

        [Display(Name = "Start Time")]
        public string? StartTime { get; set; }  // stored as "HH:mm" string for form binding

        [Display(Name = "End Time")]
        public string? EndTime { get; set; }    // stored as "HH:mm" string for form binding

        [Range(1, 500, ErrorMessage = "Capacity must be between 1 and 500.")]
        [Display(Name = "Capacity")]
        public int Capacity { get; set; } = 50;

        [StringLength(50, ErrorMessage = "Room No cannot exceed 50 characters.")]
        [Display(Name = "Room No")]
        public string? RoomNo { get; set; }

        [Display(Name = "Status")]
        public string Status { get; set; } = "Active";

        public DateTime CreatedAt { get; set; }

        // Read-only display fields (from JOINs)
        public string CourseName { get; set; } = string.Empty;
        public string AcademicYearName { get; set; } = string.Empty;
        public int EnrolledCount { get; set; }
    }

    public class BatchStatsViewModel
    {
        public int TotalBatches { get; set; }
        public int ActiveBatches { get; set; }
        public int InactiveBatches { get; set; }
        public int TotalEnrolled { get; set; }
        public int CoursesWithBatches { get; set; }
    }
}
