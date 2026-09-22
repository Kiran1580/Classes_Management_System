using System.Collections.Generic;
using System.Threading.Tasks;
using CMS_DAL.Models;

namespace CMS_DAL.Repositories.Interfaces
{
    public interface IUserRepository
    {
        Task<User?> GetByEmailAsync(string email);
        Task<User?> GetByIdAsync(int userId);
        Task<int> CreateUserAsync(User user);
        Task<bool> UpdatePasswordAsync(int userId, string passwordHash);
        Task<bool> EmailExistsAsync(string email);
        Task<IEnumerable<User>> GetAllUsersByRoleAsync(string roleName);
    }

    public interface IRoleRepository
    {
        Task<IEnumerable<Role>> GetAllRolesAsync();
        Task<Role?> GetByIdAsync(int roleId);
        Task<Role?> GetByNameAsync(string roleName);
    }

    public interface IAcademicYearRepository
    {
        Task<AcademicYear?> GetCurrentAcademicYearAsync();
        Task<IEnumerable<AcademicYear>> GetAllAsync();
        Task<int> CreateAsync(AcademicYear year);
        Task<bool> SetCurrentAcademicYearAsync(int academicYearId);
    }

    public interface IDashboardRepository
    {
        Task<AdminDashboardStats> GetAdminStatsAsync();
        Task<TeacherDashboardStats> GetTeacherStatsAsync(int userId);
        Task<StudentDashboardStats> GetStudentStatsAsync(int userId);
    }
}
