using System;
using CMS_DAL.Models;

namespace CMS_BAL.ViewModels
{
    public class UnifiedDashboardViewModel
    {
        public string RoleName { get; set; } = string.Empty;
        public string UserFullName { get; set; } = string.Empty;
        public int UserId { get; set; }

        // Role-Specific Metric Models
        public AdminDashboardStats? AdminStats { get; set; }
        public TeacherDashboardStats? TeacherStats { get; set; }
        public StudentDashboardStats? StudentStats { get; set; }
        public StudentViewModel? StudentProfile { get; set; }

        public int PendingRegistrationsCount { get; set; }

        // Role Indicators
        public bool IsAdmin => RoleName.Equals("Admin", StringComparison.OrdinalIgnoreCase);
        public bool IsTeacher => RoleName.Equals("Teacher", StringComparison.OrdinalIgnoreCase);
        public bool IsStudent => RoleName.Equals("Student", StringComparison.OrdinalIgnoreCase);

        // Student Profile Completion Check
        public bool IsStudentProfileIncomplete =>
            IsStudent &&
            StudentProfile != null &&
            (string.IsNullOrWhiteSpace(StudentProfile.Gender) ||
             !StudentProfile.DateOfBirth.HasValue ||
             string.IsNullOrWhiteSpace(StudentProfile.Address));
    }
}
