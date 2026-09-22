namespace CMS_DAL.Models
{
    public class AdminDashboardStats
    {
        public int TotalStudents { get; set; }
        public int TotalTeachers { get; set; }
        public int TotalCourses { get; set; }
        public int TotalBatches { get; set; }
        public int PendingFeeApprovals { get; set; }
        public decimal TotalCollectedRevenue { get; set; }
        public decimal PendingFeesAmount { get; set; }
        public int ActiveInquiries { get; set; }
    }

    public class TeacherDashboardStats
    {
        public int MyBatchesCount { get; set; }
        public int TotalStudentsEnrolled { get; set; }
        public int TodayLecturesCount { get; set; }
        public int UpcomingExamsCount { get; set; }
    }

    public class StudentDashboardStats
    {
        public string BatchName { get; set; } = "Not Enrolled";
        public string CourseName { get; set; } = "N/A";
        public decimal AttendancePercentage { get; set; }
        public decimal TotalFees { get; set; }
        public decimal PaidFees { get; set; }
        public decimal PendingFees { get; set; }
        public int PendingPaymentReviews { get; set; }
    }
}
