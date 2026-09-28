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
        Task<(bool Success, string Message)> RegisterStudentAsync(StudentRegisterViewModel model);
        Task<(bool Success, string Message)> RegisterTeacherAsync(TeacherRegisterViewModel model);
        Task<System.Collections.Generic.IEnumerable<PendingRegistrationUser>> GetPendingRegistrationsAsync();
        Task<(bool Success, string Message)> ApproveUserAsync(int userId);
        Task<(bool Success, string Message)> RejectUserAsync(int userId);
    }

    public interface IDashboardService
    {
        Task<AdminDashboardStats> GetAdminDashboardStatsAsync();
        Task<TeacherDashboardStats> GetTeacherDashboardStatsAsync(int userId);
        Task<StudentDashboardStats> GetStudentDashboardStatsAsync(int userId);
    }
}
