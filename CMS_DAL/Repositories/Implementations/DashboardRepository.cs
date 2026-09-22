using System;
using System.Data;
using System.Threading.Tasks;
using CMS_DAL.Helper;
using CMS_DAL.Models;
using CMS_DAL.Repositories.Interfaces;
using Microsoft.Data.SqlClient;

namespace CMS_DAL.Repositories.Implementations
{
    public class DashboardRepository : IDashboardRepository
    {
        private readonly SqlHelper _sqlHelper;

        public DashboardRepository(SqlHelper sqlHelper)
        {
            _sqlHelper = sqlHelper;
        }

        public async Task<AdminDashboardStats> GetAdminStatsAsync()
        {
            return await _sqlHelper.ExecuteSingleAsync("sp_GetAdminDashboardStats", reader => new AdminDashboardStats
            {
                TotalStudents = Convert.ToInt32(reader["TotalStudents"]),
                TotalTeachers = Convert.ToInt32(reader["TotalTeachers"]),
                TotalCourses = Convert.ToInt32(reader["TotalCourses"]),
                TotalBatches = Convert.ToInt32(reader["TotalBatches"]),
                PendingFeeApprovals = Convert.ToInt32(reader["PendingFeeApprovals"]),
                TotalCollectedRevenue = Convert.ToDecimal(reader["TotalCollectedRevenue"]),
                PendingFeesAmount = Convert.ToDecimal(reader["PendingFeesAmount"]),
                ActiveInquiries = Convert.ToInt32(reader["ActiveInquiries"])
            }, null, CommandType.StoredProcedure) ?? new AdminDashboardStats();
        }

        public async Task<TeacherDashboardStats> GetTeacherStatsAsync(int userId)
        {
            var parameters = new[] { new SqlParameter("@UserId", SqlDbType.Int) { Value = userId } };

            return await _sqlHelper.ExecuteSingleAsync("sp_GetTeacherDashboardStats", reader => new TeacherDashboardStats
            {
                MyBatchesCount = Convert.ToInt32(reader["MyBatchesCount"]),
                TotalStudentsEnrolled = Convert.ToInt32(reader["TotalStudentsEnrolled"]),
                TodayLecturesCount = Convert.ToInt32(reader["TodayLecturesCount"]),
                UpcomingExamsCount = Convert.ToInt32(reader["UpcomingExamsCount"])
            }, parameters, CommandType.StoredProcedure) ?? new TeacherDashboardStats();
        }

        public async Task<StudentDashboardStats> GetStudentStatsAsync(int userId)
        {
            var parameters = new[] { new SqlParameter("@UserId", SqlDbType.Int) { Value = userId } };

            return await _sqlHelper.ExecuteSingleAsync("sp_GetStudentDashboardStats", reader => new StudentDashboardStats
            {
                BatchName = reader["BatchName"].ToString() ?? "Not Assigned",
                CourseName = reader["CourseName"].ToString() ?? "N/A",
                TotalFees = Convert.ToDecimal(reader["TotalFees"]),
                PaidFees = Convert.ToDecimal(reader["PaidFees"]),
                PendingFees = Convert.ToDecimal(reader["PendingFees"]),
                PendingPaymentReviews = Convert.ToInt32(reader["PendingPaymentReviews"]),
                AttendancePercentage = Math.Round(Convert.ToDecimal(reader["AttendancePercentage"]), 1)
            }, parameters, CommandType.StoredProcedure) ?? new StudentDashboardStats();
        }
    }
}
