using System.Collections.Generic;
using System.Threading.Tasks;
using CMS_BAL.ViewModels;
using CMS_DAL.Models;

namespace CMS_BAL.Services.Interfaces
{
    public interface IAuthService
    {
        Task<(bool Success, string Message, User? User)> ValidateUserAsync(LoginViewModel model);
        Task<User?> GetUserByIdAsync(int userId);
        Task<User?> GetUserByEmailAsync(string email);
        Task<(bool Success, string Message)> RegisterStudentAsync(StudentRegisterViewModel model);
        Task<(bool Success, string Message)> RegisterTeacherAsync(TeacherRegisterViewModel model);
        Task<IEnumerable<PendingRegistrationUser>> GetPendingRegistrationsAsync();
        Task<(bool Success, string Message)> ApproveUserAsync(int userId);
        Task<(bool Success, string Message)> RejectUserAsync(int userId);
        Task<IEnumerable<string>> GetUserPermissionsAsync(int userId);
    }

    public interface IDashboardService
    {
        Task<AdminDashboardStats> GetAdminDashboardStatsAsync();
        Task<TeacherDashboardStats> GetTeacherDashboardStatsAsync(int userId);
        Task<StudentDashboardStats> GetStudentDashboardStatsAsync(int userId);
    }

    public interface ICourseService
    {
        // 1. Separate Paged Methods returning { Data, TotalCount }
        Task<PagedResult<CourseViewModel>> GetCoursesAsync(string? search = null, int page = 1, int pageSize = 6, string sortBy = "Id", string sortOrder = "DESC");
        Task<PagedResult<SubjectViewModel>> GetSubjectsAsync(string? search = null, int page = 1, int pageSize = 6, string sortBy = "Name", string sortOrder = "ASC");

        // 2. Simple Course CRUD
        Task<IEnumerable<CourseViewModel>> GetAllCoursesAsync(bool? isActive = null);
        Task<IEnumerable<CourseViewModel>> GetActiveCoursesAsync();
        Task<CourseViewModel?> GetCourseByIdAsync(int courseId);
        Task<(bool Success, string Message, int CourseId)> CreateCourseAsync(CourseViewModel model);
        Task<(bool Success, string Message)> UpdateCourseAsync(CourseViewModel model);
        Task<(bool Success, string Message)> DeleteCourseAsync(int courseId);

        // 3. Simple Subject CRUD
        Task<IEnumerable<SubjectViewModel>> GetAllSubjectsAsync();
        Task<SubjectViewModel?> GetSubjectByIdAsync(int subjectId);
        Task<(bool Success, string Message, int SubjectId)> CreateSubjectAsync(SubjectViewModel model);
        Task<(bool Success, string Message)> UpdateSubjectAsync(SubjectViewModel model);
        Task<(bool Success, string Message)> DeleteSubjectAsync(int subjectId);

        // 4. Mappings
        Task<IEnumerable<SubjectViewModel>> GetSubjectsByCourseIdAsync(int courseId);
        Task<bool> AssignSubjectsToCourseAsync(int courseId, IEnumerable<int> subjectIds);
    }

    public interface IBatchService
    {
        Task<PagedResult<BatchViewModel>> GetBatchesAsync(string? search = null, int page = 1, int pageSize = 6, string sortBy = "BatchId", string sortOrder = "DESC", int? courseFilter = null, string? statusFilter = null);
        Task<IEnumerable<BatchViewModel>> GetAllBatchesAsync();
        Task<BatchViewModel?> GetBatchByIdAsync(int batchId);
        Task<(bool Success, string Message, int BatchId)> CreateBatchAsync(BatchViewModel model);
        Task<(bool Success, string Message)> UpdateBatchAsync(BatchViewModel model);
        Task<(bool Success, string Message)> DeleteBatchAsync(int batchId);
        Task<BatchStatsViewModel> GetBatchStatsAsync();
    }
}
