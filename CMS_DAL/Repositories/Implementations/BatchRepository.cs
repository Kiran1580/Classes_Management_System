using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Threading.Tasks;
using CMS_DAL.Connection;
using CMS_DAL.Models;
using CMS_DAL.Repositories.Interfaces;
using Dapper;

namespace CMS_DAL.Repositories.Implementations
{
    public class BatchRepository : IBatchRepository
    {
        private readonly IDbConnectionFactory _connectionFactory;

        public BatchRepository(IDbConnectionFactory connectionFactory)
        {
            _connectionFactory = connectionFactory;
        }

        private IDbConnection connection() => _connectionFactory.CreateConnection();

        public async Task<IEnumerable<Batch>> GetAllBatchesAsync()
        {
            using (IDbConnection con = connection())
            {
                return await con.QueryAsync<Batch>(
                    "sp_GetAllBatches",
                    commandType: CommandType.StoredProcedure);
            }
        }

        public async Task<(IEnumerable<Batch> Batches, int TotalCount)> GetPagedBatchesAsync(
            string? searchTerm, int pageNumber, int pageSize,
            string sortColumn = "BatchId", string sortDirection = "DESC",
            int? courseFilter = null, string? statusFilter = null)
        {
            using (IDbConnection con = connection())
            {
                DynamicParameters parms = new DynamicParameters();
                parms.Add("@SearchTerm", string.IsNullOrWhiteSpace(searchTerm) ? null : searchTerm.Trim());
                parms.Add("@PageNumber", pageNumber < 1 ? 1 : pageNumber);
                parms.Add("@PageSize", pageSize < 1 ? 6 : pageSize);
                parms.Add("@SortColumn", string.IsNullOrWhiteSpace(sortColumn) ? "BatchId" : sortColumn.Trim());
                parms.Add("@SortDirection", string.IsNullOrWhiteSpace(sortDirection) ? "DESC" : sortDirection.Trim());
                parms.Add("@CourseFilter", courseFilter);
                parms.Add("@StatusFilter", string.IsNullOrWhiteSpace(statusFilter) ? null : statusFilter.Trim());
                parms.Add("@TotalCount", dbType: DbType.Int32, direction: ParameterDirection.Output);

                var batches = await con.QueryAsync<Batch>(
                    "sp_GetPagedBatches",
                    parms,
                    commandType: CommandType.StoredProcedure);

                int totalCount = parms.Get<int>("@TotalCount");
                return (batches, totalCount);
            }
        }

        public async Task<Batch?> GetBatchByIdAsync(int batchId)
        {
            using (IDbConnection con = connection())
            {
                DynamicParameters parms = new DynamicParameters();
                parms.Add("@BatchId", batchId);

                return await con.QueryFirstOrDefaultAsync<Batch>(
                    "sp_GetBatchById",
                    parms,
                    commandType: CommandType.StoredProcedure);
            }
        }

        public async Task<int> CreateBatchAsync(Batch batch)
        {
            using (IDbConnection con = connection())
            {
                DynamicParameters parms = new DynamicParameters();
                parms.Add("@CourseId", batch.CourseId);
                parms.Add("@AcademicYearId", batch.AcademicYearId);
                parms.Add("@BatchName", batch.BatchName.Trim());
                parms.Add("@StartDate", batch.StartDate);
                parms.Add("@EndDate", batch.EndDate);
                parms.Add("@StartTime", batch.StartTime);
                parms.Add("@EndTime", batch.EndTime);
                parms.Add("@Capacity", batch.Capacity < 1 ? 50 : batch.Capacity);
                parms.Add("@RoomNo", batch.RoomNo?.Trim());
                parms.Add("@Status", batch.Status);

                return await con.QuerySingleOrDefaultAsync<int>(
                    "sp_CreateBatch",
                    parms,
                    commandType: CommandType.StoredProcedure);
            }
        }

        public async Task<int> UpdateBatchAsync(Batch batch)
        {
            using (IDbConnection con = connection())
            {
                DynamicParameters parms = new DynamicParameters();
                parms.Add("@BatchId", batch.BatchId);
                parms.Add("@CourseId", batch.CourseId);
                parms.Add("@AcademicYearId", batch.AcademicYearId);
                parms.Add("@BatchName", batch.BatchName.Trim());
                parms.Add("@StartDate", batch.StartDate);
                parms.Add("@EndDate", batch.EndDate);
                parms.Add("@StartTime", batch.StartTime);
                parms.Add("@EndTime", batch.EndTime);
                parms.Add("@Capacity", batch.Capacity < 1 ? 50 : batch.Capacity);
                parms.Add("@RoomNo", batch.RoomNo?.Trim());
                parms.Add("@Status", batch.Status);

                return await con.QuerySingleOrDefaultAsync<int>(
                    "sp_UpdateBatch",
                    parms,
                    commandType: CommandType.StoredProcedure);
            }
        }

        public async Task<int> DeleteBatchAsync(int batchId)
        {
            using (IDbConnection con = connection())
            {
                DynamicParameters parms = new DynamicParameters();
                parms.Add("@BatchId", batchId);

                return await con.QuerySingleOrDefaultAsync<int>(
                    "sp_DeleteBatch",
                    parms,
                    commandType: CommandType.StoredProcedure);
            }
        }

        public async Task<(int TotalBatches, int ActiveBatches, int InactiveBatches, int TotalEnrolled, int CoursesWithBatches)> GetBatchStatsAsync()
        {
            using (IDbConnection con = connection())
            {
                var row = await con.QueryFirstOrDefaultAsync(
                    "sp_GetBatchStats",
                    commandType: CommandType.StoredProcedure);

                if (row == null) return (0, 0, 0, 0, 0);

                return (
                    (int)(row.TotalBatches ?? 0),
                    (int)(row.ActiveBatches ?? 0),
                    (int)(row.InactiveBatches ?? 0),
                    (int)(row.TotalEnrolled ?? 0),
                    (int)(row.CoursesWithBatches ?? 0)
                );
            }
        }

        public async Task<IEnumerable<BatchFacultyAssignment>> GetBatchFacultyAssignmentsAsync(int batchId)
        {
            using (IDbConnection con = connection())
            {
                var parms = new DynamicParameters();
                parms.Add("@BatchId", batchId);

                return await con.QueryAsync<BatchFacultyAssignment>(
                    "sp_GetBatchFacultyAssignments",
                    parms,
                    commandType: CommandType.StoredProcedure);
            }
        }

        public async Task<bool> SaveBatchFacultyAssignmentsAsync(int batchId, IEnumerable<BatchFacultyAssignmentSaveRequest> assignments)
        {
            using (IDbConnection con = connection())
            {
                if (con.State != ConnectionState.Open)
                    con.Open();

                using (var tran = con.BeginTransaction())
                {
                    try
                    {
                        foreach (var item in assignments)
                        {
                            var parms = new DynamicParameters();
                            parms.Add("@BatchId", batchId);
                            parms.Add("@SubjectId", item.SubjectId);
                            parms.Add("@TeacherId", item.TeacherId.HasValue && item.TeacherId.Value > 0 ? item.TeacherId.Value : (int?)null);

                            await con.ExecuteAsync(
                                "sp_SaveBatchFacultyAssignment",
                                parms,
                                transaction: tran,
                                commandType: CommandType.StoredProcedure);
                        }

                        tran.Commit();
                        return true;
                    }
                    catch
                    {
                        tran.Rollback();
                        throw;
                    }
                }
            }
        }
    }
}
