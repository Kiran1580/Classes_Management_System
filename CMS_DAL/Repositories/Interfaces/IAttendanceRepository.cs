using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using CMS_DAL.Models;

namespace CMS_DAL.Repositories.Interfaces
{
    public interface IAttendanceRepository
    {
        Task<IEnumerable<AttendanceStudentItem>> GetStudentsForAttendanceAsync(int batchId, DateTime sessionDate, int? subjectId = null);
        Task<(int SessionId, int TotalMarked)> SaveBatchAttendanceAsync(SaveBatchAttendanceRequest request);
        Task<(IEnumerable<AttendanceGridItem> Items, int TotalCount, int TotalPresent, int TotalAbsent, int TotalLate)> GetPagedAttendanceRecordsAsync(
            string? searchTerm, int? batchId, int? courseId, DateTime? fromDate, DateTime? toDate, string? status,
            int? teacherId, int pageNumber, int pageSize, string sortColumn = "SessionDate", string sortDirection = "DESC");
        Task<(IEnumerable<StudentAttendanceGridItem> Items, int TotalCount, int TotalClasses, int AttendedClasses, int AbsentClasses, int LateClasses, decimal AttendancePercentage)> GetPagedStudentAttendanceAsync(
            int studentId, DateTime? fromDate, DateTime? toDate, string? status, int pageNumber, int pageSize,
            string sortColumn = "SessionDate", string sortDirection = "DESC");
        Task<AttendanceDashboardStats> GetAttendanceDashboardStatsAsync(int? teacherId = null);
    }
}
