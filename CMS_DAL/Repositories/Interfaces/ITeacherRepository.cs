using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using CMS_DAL.Models;

namespace CMS_DAL.Repositories.Interfaces
{
    public interface ITeacherRepository
    {
        Task<(IEnumerable<Teacher> Teachers, int TotalCount)> GetPagedTeachersAsync(
            string? searchTerm,
            int pageNumber,
            int pageSize,
            string? sortColumn,
            string? sortDirection,
            string? statusFilter);

        Task<Teacher?> GetTeacherByIdAsync(int teacherId);

        Task<Teacher?> GetTeacherByUserIdAsync(int userId);

        Task<IEnumerable<TeacherBatch>> GetTeacherBatchesAsync(int teacherId);

        Task<(int Total, int Active, int Inactive, int AssignedBatches)> GetTeacherStatsAsync();

        Task<string> GetNextEmployeeCodeAsync(string prefix = "TCH");

        Task<int> CreateTeacherAsync(Teacher teacher, string passwordHash);

        Task<int> UpdateTeacherAsync(Teacher teacher);

        Task<int> DeleteTeacherAsync(int teacherId);

        Task<IEnumerable<Teacher>> GetAllActiveTeachersAsync();
    }
}
