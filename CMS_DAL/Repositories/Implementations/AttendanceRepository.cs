using System;
using System.Collections.Generic;
using System.Data;
using System.Text.Json;
using System.Threading.Tasks;
using CMS_DAL.Connection;
using CMS_DAL.Models;
using CMS_DAL.Repositories.Interfaces;
using Dapper;

namespace CMS_DAL.Repositories.Implementations
{
    public class AttendanceRepository : IAttendanceRepository
    {
        private readonly IDbConnectionFactory _connectionFactory;

        public AttendanceRepository(IDbConnectionFactory connectionFactory)
        {
            _connectionFactory = connectionFactory;
        }

        private IDbConnection CreateConnection() => _connectionFactory.CreateConnection();

        public async Task<IEnumerable<AttendanceStudentItem>> GetStudentsForAttendanceAsync(int batchId, DateTime sessionDate, int? subjectId = null)
        {
            using (IDbConnection con = CreateConnection())
            {
                var parms = new DynamicParameters();
                parms.Add("@BatchId", batchId);
                parms.Add("@SessionDate", sessionDate.Date);
                parms.Add("@SubjectId", subjectId);

                return await con.QueryAsync<AttendanceStudentItem>(
                    "sp_GetStudentsForAttendance",
                    parms,
                    commandType: CommandType.StoredProcedure);
            }
        }

        public async Task<(int SessionId, int TotalMarked)> SaveBatchAttendanceAsync(SaveBatchAttendanceRequest request)
        {
            using (IDbConnection con = CreateConnection())
            {
                var json = JsonSerializer.Serialize(request.Students);

                var parms = new DynamicParameters();
                parms.Add("@BatchId", request.BatchId);
                parms.Add("@SubjectId", request.SubjectId);
                parms.Add("@TeacherId", request.TeacherId);
                parms.Add("@SessionDate", request.SessionDate.Date);
                parms.Add("@Topic", string.IsNullOrWhiteSpace(request.Topic) ? null : request.Topic.Trim());
                parms.Add("@AttendanceJson", json);
                parms.Add("@SessionId", dbType: DbType.Int32, direction: ParameterDirection.Output);
                parms.Add("@TotalMarked", dbType: DbType.Int32, direction: ParameterDirection.Output);

                await con.ExecuteAsync(
                    "sp_SaveBatchAttendance",
                    parms,
                    commandType: CommandType.StoredProcedure);

                int sessionId = parms.Get<int>("@SessionId");
                int totalMarked = parms.Get<int>("@TotalMarked");

                return (sessionId, totalMarked);
            }
        }

        public async Task<(IEnumerable<AttendanceGridItem> Items, int TotalCount, int TotalPresent, int TotalAbsent, int TotalLate)> GetPagedAttendanceRecordsAsync(
            string? searchTerm, int? batchId, int? courseId, DateTime? fromDate, DateTime? toDate, string? status,
            int? teacherId, int pageNumber, int pageSize, string sortColumn = "SessionDate", string sortDirection = "DESC")
        {
            using (IDbConnection con = CreateConnection())
            {
                var parms = new DynamicParameters();
                parms.Add("@SearchTerm", string.IsNullOrWhiteSpace(searchTerm) ? null : searchTerm.Trim());
                parms.Add("@BatchId", batchId);
                parms.Add("@CourseId", courseId);
                parms.Add("@FromDate", fromDate?.Date);
                parms.Add("@ToDate", toDate?.Date);
                parms.Add("@Status", string.IsNullOrWhiteSpace(status) ? null : status.Trim());
                parms.Add("@TeacherId", teacherId);
                parms.Add("@PageNumber", pageNumber < 1 ? 1 : pageNumber);
                parms.Add("@PageSize", pageSize < 1 ? 10 : pageSize);
                parms.Add("@SortColumn", string.IsNullOrWhiteSpace(sortColumn) ? "SessionDate" : sortColumn.Trim());
                parms.Add("@SortDirection", string.IsNullOrWhiteSpace(sortDirection) ? "DESC" : sortDirection.Trim());

                parms.Add("@TotalCount", dbType: DbType.Int32, direction: ParameterDirection.Output);
                parms.Add("@TotalPresent", dbType: DbType.Int32, direction: ParameterDirection.Output);
                parms.Add("@TotalAbsent", dbType: DbType.Int32, direction: ParameterDirection.Output);
                parms.Add("@TotalLate", dbType: DbType.Int32, direction: ParameterDirection.Output);

                var items = await con.QueryAsync<AttendanceGridItem>(
                    "sp_GetPagedAttendanceRecords",
                    parms,
                    commandType: CommandType.StoredProcedure);

                int totalCount = parms.Get<int?>("@TotalCount") ?? 0;
                int totalPresent = parms.Get<int?>("@TotalPresent") ?? 0;
                int totalAbsent = parms.Get<int?>("@TotalAbsent") ?? 0;
                int totalLate = parms.Get<int?>("@TotalLate") ?? 0;

                return (items, totalCount, totalPresent, totalAbsent, totalLate);
            }
        }

        public async Task<(IEnumerable<StudentAttendanceGridItem> Items, int TotalCount, int TotalClasses, int AttendedClasses, int AbsentClasses, int LateClasses, decimal AttendancePercentage)> GetPagedStudentAttendanceAsync(
            int studentId, DateTime? fromDate, DateTime? toDate, string? status, int pageNumber, int pageSize,
            string sortColumn = "SessionDate", string sortDirection = "DESC")
        {
            using (IDbConnection con = CreateConnection())
            {
                var parms = new DynamicParameters();
                parms.Add("@StudentId", studentId);
                parms.Add("@FromDate", fromDate?.Date);
                parms.Add("@ToDate", toDate?.Date);
                parms.Add("@Status", string.IsNullOrWhiteSpace(status) ? null : status.Trim());
                parms.Add("@PageNumber", pageNumber < 1 ? 1 : pageNumber);
                parms.Add("@PageSize", pageSize < 1 ? 10 : pageSize);
                parms.Add("@SortColumn", string.IsNullOrWhiteSpace(sortColumn) ? "SessionDate" : sortColumn.Trim());
                parms.Add("@SortDirection", string.IsNullOrWhiteSpace(sortDirection) ? "DESC" : sortDirection.Trim());

                parms.Add("@TotalCount", dbType: DbType.Int32, direction: ParameterDirection.Output);
                parms.Add("@TotalClasses", dbType: DbType.Int32, direction: ParameterDirection.Output);
                parms.Add("@AttendedClasses", dbType: DbType.Int32, direction: ParameterDirection.Output);
                parms.Add("@AbsentClasses", dbType: DbType.Int32, direction: ParameterDirection.Output);
                parms.Add("@LateClasses", dbType: DbType.Int32, direction: ParameterDirection.Output);
                parms.Add("@AttendancePercentage", dbType: DbType.Decimal, precision: 5, scale: 2, direction: ParameterDirection.Output);

                var items = await con.QueryAsync<StudentAttendanceGridItem>(
                    "sp_GetPagedStudentAttendance",
                    parms,
                    commandType: CommandType.StoredProcedure);

                int totalCount = parms.Get<int?>("@TotalCount") ?? 0;
                int totalClasses = parms.Get<int?>("@TotalClasses") ?? 0;
                int attendedClasses = parms.Get<int?>("@AttendedClasses") ?? 0;
                int absentClasses = parms.Get<int?>("@AbsentClasses") ?? 0;
                int lateClasses = parms.Get<int?>("@LateClasses") ?? 0;
                decimal percentage = parms.Get<decimal?>("@AttendancePercentage") ?? 0m;

                return (items, totalCount, totalClasses, attendedClasses, absentClasses, lateClasses, percentage);
            }
        }

        public async Task<AttendanceDashboardStats> GetAttendanceDashboardStatsAsync(int? teacherId = null)
        {
            using (IDbConnection con = CreateConnection())
            {
                var parms = new DynamicParameters();
                parms.Add("@TeacherId", teacherId);

                var stats = await con.QueryFirstOrDefaultAsync<AttendanceDashboardStats>(
                    "sp_GetAttendanceDashboardStats",
                    parms,
                    commandType: CommandType.StoredProcedure);

                return stats ?? new AttendanceDashboardStats { TodayDate = DateTime.Today };
            }
        }
    }
}
