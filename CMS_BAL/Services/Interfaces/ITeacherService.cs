using System.Collections.Generic;
using System.Threading.Tasks;
using CMS_BAL.ViewModels;

namespace CMS_BAL.Services.Interfaces
{
    public interface ITeacherService
    {
        Task<PagedResult<TeacherViewModel>> GetTeachersAsync(
            string? search,
            int page,
            int pageSize,
            string? sortBy,
            string? sortOrder,
            string? statusFilter);

        Task<TeacherViewModel?> GetTeacherByIdAsync(int teacherId);

        Task<TeacherViewModel?> GetTeacherByUserIdAsync(int userId);

        Task<TeacherDetailsViewModel?> GetTeacherDetailsAsync(int teacherId);

        Task<IEnumerable<TeacherBatchViewModel>> GetTeacherBatchesAsync(int teacherId);

        Task<TeacherStatsViewModel> GetTeacherStatsAsync();

        Task<string> GetNextEmployeeCodeAsync();

        Task<(bool Success, string Message, int TeacherId)> CreateTeacherAsync(TeacherCreateViewModel model);

        Task<(bool Success, string Message)> UpdateTeacherAsync(TeacherEditViewModel model);

        Task<(bool Success, string Message)> DeleteTeacherAsync(int teacherId);

        Task<IEnumerable<TeacherViewModel>> GetAllActiveTeachersAsync();
    }
}
