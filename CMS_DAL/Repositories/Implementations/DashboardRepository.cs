using System.Data;
using System.Threading.Tasks;
using CMS_DAL.Connection;
using CMS_DAL.Models;
using CMS_DAL.Repositories.Interfaces;
using Dapper;

namespace CMS_DAL.Repositories.Implementations
{
    public class DashboardRepository : IDashboardRepository
    {
        private readonly IDbConnectionFactory _connectionFactory;

        public DashboardRepository(IDbConnectionFactory connectionFactory)
        {
            _connectionFactory = connectionFactory;
        }

        private IDbConnection connection() => _connectionFactory.CreateConnection();

        public async Task<AdminDashboardStats> GetAdminStatsAsync()
        {
            using (IDbConnection con = connection())
            {
                var stats = await con.QueryFirstOrDefaultAsync<AdminDashboardStats>(
                    "sp_GetAdminDashboardStats", 
                    commandType: CommandType.StoredProcedure);

                return stats ?? new AdminDashboardStats();
            }
        }

        public async Task<TeacherDashboardStats> GetTeacherStatsAsync(int userId)
        {
            using (IDbConnection con = connection())
            {
                DynamicParameters parms = new DynamicParameters();
                parms.Add("@UserId", userId);

                var stats = await con.QueryFirstOrDefaultAsync<TeacherDashboardStats>(
                    "sp_GetTeacherDashboardStats", 
                    parms, 
                    commandType: CommandType.StoredProcedure);

                return stats ?? new TeacherDashboardStats();
            }
        }

        public async Task<StudentDashboardStats> GetStudentStatsAsync(int userId)
        {
            using (IDbConnection con = connection())
            {
                DynamicParameters parms = new DynamicParameters();
                parms.Add("@UserId", userId);

                var stats = await con.QueryFirstOrDefaultAsync<StudentDashboardStats>(
                    "sp_GetStudentDashboardStats", 
                    parms, 
                    commandType: CommandType.StoredProcedure);

                return stats ?? new StudentDashboardStats();
            }
        }
    }
}
