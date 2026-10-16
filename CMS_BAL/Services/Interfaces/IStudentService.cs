using System.Collections.Generic;
using System.Threading.Tasks;
using CMS_BAL.ViewModels;

namespace CMS_BAL.Services.Interfaces
{
    public interface IStudentService
    {
        Task<PagedResult<StudentViewModel>> GetStudentsAsync(
            string? search = null,
            int page = 1,
            int pageSize = 6,
            string sortBy = "StudentId",
            string sortOrder = "DESC",
            int? courseId = null,
            int? batchId = null,
            string? statusFilter = null);

        Task<StudentViewModel?> GetStudentByIdAsync(int studentId);

        Task<StudentViewModel?> GetStudentByUserIdAsync(int userId);

        Task<(bool Success, string Message)> UpdateStudentProfileAsync(int studentId, string? gender, DateTime? dateOfBirth, string? address, string? profileImage);

        Task<StudentAdmissionViewModel?> GetStudentForEditAsync(int studentId);

        Task<(bool Success, string Message, int StudentId)> CreateStudentAdmissionAsync(StudentAdmissionViewModel model);

        Task<(bool Success, string Message)> UpdateStudentAsync(StudentAdmissionViewModel model);

        Task<(bool Success, string Message)> DeleteStudentAsync(int studentId);

        Task<StudentStatsViewModel> GetStudentStatsAsync();

        Task<string> GetNextAdmissionNumberAsync();

        Task<IEnumerable<BatchViewModel>> GetBatchesByCourseAsync(int courseId);

        Task<StudentCoursesAndBatchesViewModel> GetStudentCoursesAndBatchesAsync(int? userId = null, int? studentId = null);
    }
}
