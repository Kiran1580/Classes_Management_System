using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using CMS_BAL.Services.Interfaces;
using CMS_DAL.Models;
using CMS_DAL.Repositories.Interfaces;

namespace CMS_BAL.Services.Implementations
{
    public class AttendanceService : IAttendanceService
    {
        private readonly IAttendanceRepository _attendanceRepository;

        public AttendanceService(IAttendanceRepository attendanceRepository)
        {
            _attendanceRepository = attendanceRepository;
        }

        public async Task<IEnumerable<AttendanceStudentItem>> GetStudentsForAttendanceAsync(int batchId, DateTime sessionDate, int? subjectId = null)
        {
            return await _attendanceRepository.GetStudentsForAttendanceAsync(batchId, sessionDate, subjectId);
        }

        public async Task<(int SessionId, int TotalMarked)> SaveBatchAttendanceAsync(SaveBatchAttendanceRequest request)
        {
            if (request.BatchId <= 0)
                throw new ArgumentException("Invalid Batch ID.");

            if (request.SessionDate > DateTime.Today.AddDays(1))
                throw new ArgumentException("Cannot mark attendance for future dates.");

            return await _attendanceRepository.SaveBatchAttendanceAsync(request);
        }

        public async Task<(IEnumerable<AttendanceGridItem> Items, int TotalCount, int TotalPresent, int TotalAbsent, int TotalLate)> GetPagedAttendanceRecordsAsync(
            string? searchTerm, int? batchId, int? courseId, DateTime? fromDate, DateTime? toDate, string? status,
            int? teacherId, int pageNumber, int pageSize, string sortColumn = "SessionDate", string sortDirection = "DESC")
        {
            return await _attendanceRepository.GetPagedAttendanceRecordsAsync(
                searchTerm, batchId, courseId, fromDate, toDate, status, teacherId, pageNumber, pageSize, sortColumn, sortDirection);
        }

        public async Task<(IEnumerable<StudentAttendanceGridItem> Items, int TotalCount, int TotalClasses, int AttendedClasses, int AbsentClasses, int LateClasses, decimal AttendancePercentage)> GetPagedStudentAttendanceAsync(
            int studentId, DateTime? fromDate, DateTime? toDate, string? status, int pageNumber, int pageSize,
            string sortColumn = "SessionDate", string sortDirection = "DESC")
        {
            return await _attendanceRepository.GetPagedStudentAttendanceAsync(
                studentId, fromDate, toDate, status, pageNumber, pageSize, sortColumn, sortDirection);
        }

        public async Task<AttendanceDashboardStats> GetAttendanceDashboardStatsAsync(int? teacherId = null)
        {
            return await _attendanceRepository.GetAttendanceDashboardStatsAsync(teacherId);
        }
    }
}
