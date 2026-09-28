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
                return (false, "Your account is pending Admin approval. You will be able to log in once an Administrator verifies and activates your account.", null);
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

        public async Task<(bool Success, string Message)> RegisterStudentAsync(StudentRegisterViewModel model)
        {
            if (await _userRepository.EmailExistsAsync(model.Email))
            {
                return (false, "An account with this email address already exists.");
            }

            var passwordHash = BCrypt.Net.BCrypt.HashPassword(model.Password);

            int userId = await _userRepository.RegisterStudentAsync(
                model.FullName,
                model.Email,
                model.Mobile,
                passwordHash,
                model.ParentName,
                model.ParentMobile);

            if (userId <= 0)
            {
                return (false, "Registration could not be completed. Please try again.");
            }

            return (true, "Student registration submitted successfully! Your account will be activated once approved by Administrator.");
        }

        public async Task<(bool Success, string Message)> RegisterTeacherAsync(TeacherRegisterViewModel model)
        {
            if (await _userRepository.EmailExistsAsync(model.Email))
            {
                return (false, "An account with this email address already exists.");
            }

            var passwordHash = BCrypt.Net.BCrypt.HashPassword(model.Password);

            int userId = await _userRepository.RegisterTeacherAsync(
                model.FullName,
                model.Email,
                model.Mobile,
                passwordHash,
                model.Qualification,
                model.SubjectSpecialization);

            if (userId <= 0)
            {
                return (false, "Registration could not be completed. Please try again.");
            }

            return (true, "Faculty registration submitted successfully! Your account will be activated once approved by Administrator.");
        }

        public async Task<System.Collections.Generic.IEnumerable<PendingRegistrationUser>> GetPendingRegistrationsAsync()
        {
            return await _userRepository.GetPendingRegistrationsAsync();
        }

        public async Task<(bool Success, string Message)> ApproveUserAsync(int userId)
        {
            bool approved = await _userRepository.ApproveUserAsync(userId);
            if (approved)
            {
                return (true, "Account approved and activated successfully.");
            }
            return (false, "Failed to approve account. Please try again.");
        }

        public async Task<(bool Success, string Message)> RejectUserAsync(int userId)
        {
            bool rejected = await _userRepository.RejectUserAsync(userId);
            if (rejected)
            {
                return (true, "Registration request rejected and removed.");
            }
            return (false, "Failed to reject request. Please try again.");
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
