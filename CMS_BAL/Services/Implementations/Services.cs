using System;
using System.Threading.Tasks;
using CMS_DAL.Models;
using CMS_BAL.Services.Interfaces;
using CMS_BAL.ViewModels;
using CMS_DAL.Repositories.Interfaces;

namespace CMS_BAL.Services.Implementations
{
    public class AuthService : IAuthService
    {
        private readonly IUserRepository _userRepository;

        public AuthService(IUserRepository userRepository)
        {
            _userRepository = userRepository;
        }

        public async Task<(bool Success, string Message, User? User)> ValidateUserAsync(LoginViewModel model)
        {
            if (string.IsNullOrWhiteSpace(model.Email) || string.IsNullOrWhiteSpace(model.Password))
            {
                return (false, "Email and password are required.", null);
            }

            var user = await _userRepository.GetByEmailAsync(model.Email.Trim());
            if (user == null)
            {
                return (false, "Invalid email or password.", null);
            }

            if (!user.IsActive)
            {
                return (false, "Your account is deactivated. Please contact administrator.", null);
            }

            bool isPasswordValid = false;
            try
            {
                isPasswordValid = BCrypt.Net.BCrypt.Verify(model.Password, user.PasswordHash);
            }
            catch
            {
                // In case of unhashed legacy string during migration/testing
                if (user.PasswordHash == model.Password)
                {
                    isPasswordValid = true;
                    // Re-hash with BCrypt
                    var newHash = BCrypt.Net.BCrypt.HashPassword(model.Password);
                    await _userRepository.UpdatePasswordAsync(user.UserId, newHash);
                }
            }

            if (!isPasswordValid)
            {
                return (false, "Invalid email or password.", null);
            }

            return (true, "Login successful.", user);
        }

        public async Task<User?> GetUserByIdAsync(int userId)
        {
            return await _userRepository.GetByIdAsync(userId);
        }

        public async Task<User?> GetUserByEmailAsync(string email)
        {
            return await _userRepository.GetByEmailAsync(email);
        }
    }

    public class DashboardService : IDashboardService
    {
        private readonly IDashboardRepository _dashboardRepository;

        public DashboardService(IDashboardRepository dashboardRepository)
        {
            _dashboardRepository = dashboardRepository;
        }

        public async Task<AdminDashboardStats> GetAdminDashboardStatsAsync()
        {
            return await _dashboardRepository.GetAdminStatsAsync();
        }

        public async Task<TeacherDashboardStats> GetTeacherDashboardStatsAsync(int userId)
        {
            return await _dashboardRepository.GetTeacherStatsAsync(userId);
        }

        public async Task<StudentDashboardStats> GetStudentDashboardStatsAsync(int userId)
        {
            return await _dashboardRepository.GetStudentStatsAsync(userId);
        }
    }
}
