using System.Threading.Tasks;
using CMS_DAL.Models;
using CMS_BAL.ViewModels;

namespace CMS_BAL.Services.Interfaces
{
    public interface IAuthService
    {
        Task<(bool Success, string Message, User? User)> ValidateUserAsync(LoginViewModel model);
        Task<User?> GetUserByIdAsync(int userId);
        Task<User?> GetUserByEmailAsync(string email);
    }

    public interface IDashboardService
    {
        Task<AdminDashboardStats> GetAdminDashboardStatsAsync();
        Task<TeacherDashboardStats> GetTeacherDashboardStatsAsync(int userId);
        Task<StudentDashboardStats> GetStudentDashboardStatsAsync(int userId);
    }
}
