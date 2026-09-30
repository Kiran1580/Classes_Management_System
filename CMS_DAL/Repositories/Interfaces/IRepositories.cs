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
        Task<int> RegisterStudentAsync(string fullName, string email, string? mobile, string passwordHash, string? parentName, string? parentMobile);
        Task<int> RegisterTeacherAsync(string fullName, string email, string? mobile, string passwordHash, string? qualification, string? subjectSpecialization);
        Task<IEnumerable<PendingRegistrationUser>> GetPendingRegistrationsAsync();
        Task<bool> ApproveUserAsync(int userId);
        Task<bool> RejectUserAsync(int userId);
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

    public interface ICourseRepository
    {
        Task<IEnumerable<Course>> GetAllCoursesAsync();
        Task<(IEnumerable<Course> Courses, int TotalCount)> GetPagedCoursesAsync(string? searchTerm, int pageNumber, int pageSize, string sortColumn = "Id", string sortDirection = "DESC");
        Task<Course?> GetCourseByIdAsync(int courseId);
        Task<int> CreateCourseAsync(Course course);
        Task<int> UpdateCourseAsync(Course course);
        Task<int> DeleteCourseAsync(int courseId);

        Task<IEnumerable<Subject>> GetAllSubjectsAsync();
        Task<(IEnumerable<Subject> Subjects, int TotalCount)> GetPagedSubjectsAsync(string? searchTerm, int pageNumber, int pageSize, string sortColumn = "Id", string sortDirection = "DESC");
        Task<Subject?> GetSubjectByIdAsync(int subjectId);
        Task<int> CreateSubjectAsync(Subject subject);
        Task<int> UpdateSubjectAsync(Subject subject);
        Task<int> DeleteSubjectAsync(int subjectId);

        Task<IEnumerable<Subject>> GetSubjectsByCourseIdAsync(int courseId);
        Task<bool> AssignSubjectsToCourseAsync(int courseId, IEnumerable<int> subjectIds);
    }
}
