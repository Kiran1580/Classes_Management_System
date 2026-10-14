using System;
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
    public class TeacherRepository : ITeacherRepository
    {
        private readonly IDbConnectionFactory _connectionFactory;

        public TeacherRepository(IDbConnectionFactory connectionFactory)
        {
            _connectionFactory = connectionFactory;
        }

        private IDbConnection CreateConnection() => _connectionFactory.CreateConnection();

        public async Task<(IEnumerable<Teacher> Teachers, int TotalCount)> GetPagedTeachersAsync(
            string? searchTerm,
            int pageNumber,
            int pageSize,
            string? sortColumn,
            string? sortDirection,
            string? statusFilter)
        {
            using (IDbConnection con = CreateConnection())
            {
                var parms = new DynamicParameters();
                parms.Add("@SearchTerm", string.IsNullOrWhiteSpace(searchTerm) ? null : searchTerm.Trim());
                parms.Add("@PageNumber", pageNumber < 1 ? 1 : pageNumber);
                parms.Add("@PageSize", pageSize < 1 ? 10 : pageSize);
                parms.Add("@SortColumn", string.IsNullOrWhiteSpace(sortColumn) ? "TeacherId" : sortColumn.Trim());
                parms.Add("@SortDirection", string.IsNullOrWhiteSpace(sortDirection) ? "DESC" : sortDirection.Trim());
                parms.Add("@StatusFilter", string.IsNullOrWhiteSpace(statusFilter) ? null : statusFilter.Trim());

                using (var multi = await con.QueryMultipleAsync("sp_GetPagedTeachers", parms, commandType: CommandType.StoredProcedure))
                {
                    int totalCount = await multi.ReadFirstAsync<int>();
                    var teachers = await multi.ReadAsync<Teacher>();
                    return (teachers, totalCount);
                }
            }
        }

        public async Task<Teacher?> GetTeacherByIdAsync(int teacherId)
        {
            using (IDbConnection con = CreateConnection())
            {
                var parms = new DynamicParameters();
                parms.Add("@TeacherId", teacherId);

                return await con.QuerySingleOrDefaultAsync<Teacher>(
                    "sp_GetTeacherById",
                    parms,
                    commandType: CommandType.StoredProcedure);
            }
        }

        public async Task<Teacher?> GetTeacherByUserIdAsync(int userId)
        {
            using (IDbConnection con = CreateConnection())
            {
                var parms = new DynamicParameters();
                parms.Add("@UserId", userId);

                return await con.QuerySingleOrDefaultAsync<Teacher>(
                    "sp_GetTeacherByUserId",
                    parms,
                    commandType: CommandType.StoredProcedure);
            }
        }

        public async Task<IEnumerable<TeacherBatch>> GetTeacherBatchesAsync(int teacherId)
        {
            using (IDbConnection con = CreateConnection())
            {
                var parms = new DynamicParameters();
                parms.Add("@TeacherId", teacherId);

                return await con.QueryAsync<TeacherBatch>(
                    "sp_GetTeacherBatches",
                    parms,
                    commandType: CommandType.StoredProcedure);
            }
        }

        public async Task<(int Total, int Active, int Inactive, int AssignedBatches)> GetTeacherStatsAsync()
        {
            using (IDbConnection con = CreateConnection())
            {
                var row = await con.QueryFirstOrDefaultAsync(
                    "sp_GetTeacherStats",
                    commandType: CommandType.StoredProcedure);

                if (row == null) return (0, 0, 0, 0);

                return (
                    (int)(row.TotalTeachers ?? 0),
                    (int)(row.ActiveTeachers ?? 0),
                    (int)(row.InactiveTeachers ?? 0),
                    (int)(row.AssignedBatchesCount ?? 0)
                );
            }
        }

        public async Task<string> GetNextEmployeeCodeAsync(string prefix = "TCH")
        {
            using (IDbConnection con = CreateConnection())
            {
                var parms = new DynamicParameters();
                parms.Add("@Prefix", prefix);

                var result = await con.QuerySingleOrDefaultAsync<string>(
                    "sp_GetNextEmployeeCode",
                    parms,
                    commandType: CommandType.StoredProcedure);

                return result ?? $"{prefix}-{DateTime.Now.Year}-0001";
            }
        }

        public async Task<int> CreateTeacherAsync(Teacher teacher, string passwordHash)
        {
            using (IDbConnection con = CreateConnection())
            {
                var parms = new DynamicParameters();
                parms.Add("@EmployeeCode", teacher.EmployeeCode);
                parms.Add("@FirstName", teacher.FirstName);
                parms.Add("@LastName", teacher.LastName);
                parms.Add("@Mobile", teacher.Mobile);
                parms.Add("@Email", teacher.Email);
                parms.Add("@Qualification", teacher.Qualification);
                parms.Add("@JoiningDate", teacher.JoiningDate);
                parms.Add("@ProfileImage", teacher.ProfileImage);
                parms.Add("@PasswordHash", passwordHash);
                parms.Add("@IsActive", teacher.IsActive);

                return await con.QuerySingleOrDefaultAsync<int>(
                    "sp_CreateTeacher",
                    parms,
                    commandType: CommandType.StoredProcedure);
            }
        }

        public async Task<int> UpdateTeacherAsync(Teacher teacher)
        {
            using (IDbConnection con = CreateConnection())
            {
                var parms = new DynamicParameters();
                parms.Add("@TeacherId", teacher.TeacherId);
                parms.Add("@FirstName", teacher.FirstName);
                parms.Add("@LastName", teacher.LastName);
                parms.Add("@Mobile", teacher.Mobile);
                parms.Add("@Email", teacher.Email);
                parms.Add("@Qualification", teacher.Qualification);
                parms.Add("@JoiningDate", teacher.JoiningDate);
                parms.Add("@ProfileImage", teacher.ProfileImage);
                parms.Add("@IsActive", teacher.IsActive);

                return await con.QuerySingleOrDefaultAsync<int>(
                    "sp_UpdateTeacher",
                    parms,
                    commandType: CommandType.StoredProcedure);
            }
        }

        public async Task<int> DeleteTeacherAsync(int teacherId)
        {
            using (IDbConnection con = CreateConnection())
            {
                var parms = new DynamicParameters();
                parms.Add("@TeacherId", teacherId);

                return await con.QuerySingleOrDefaultAsync<int>(
                    "sp_DeleteTeacher",
                    parms,
                    commandType: CommandType.StoredProcedure);
            }
        }

        public async Task<IEnumerable<Teacher>> GetAllActiveTeachersAsync()
        {
            using (IDbConnection con = CreateConnection())
            {
                return await con.QueryAsync<Teacher>(
                    "sp_GetAllActiveTeachers",
                    commandType: CommandType.StoredProcedure);
            }
        }
    }
}
