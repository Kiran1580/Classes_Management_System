using System.Collections.Generic;
using System.Data;
using System.Threading.Tasks;
using CMS_DAL.Connection;
using CMS_DAL.Models;
using CMS_DAL.Repositories.Interfaces;
using Dapper;

namespace CMS_DAL.Repositories.Implementations
{
    public class AcademicYearRepository : IAcademicYearRepository
    {
        private readonly IDbConnectionFactory _connectionFactory;

        public AcademicYearRepository(IDbConnectionFactory connectionFactory)
        {
            _connectionFactory = connectionFactory;
        }

        private IDbConnection connection() => _connectionFactory.CreateConnection();

        public async Task<AcademicYear?> GetCurrentAcademicYearAsync()
        {
            using (IDbConnection con = connection())
            {
                return await con.QueryFirstOrDefaultAsync<AcademicYear>(
                    "sp_GetCurrentAcademicYear", 
                    commandType: CommandType.StoredProcedure);
            }
        }

        public async Task<IEnumerable<AcademicYear>> GetAllAsync()
        {
            using (IDbConnection con = connection())
            {
                return await con.QueryAsync<AcademicYear>(
                    "sp_GetAllAcademicYears", 
                    commandType: CommandType.StoredProcedure);
            }
        }

        public async Task<int> CreateAsync(AcademicYear year)
        {
            using (IDbConnection con = connection())
            {
                DynamicParameters parms = new DynamicParameters();
                parms.Add("@YearName", year.YearName);
                parms.Add("@StartDate", year.StartDate);
                parms.Add("@EndDate", year.EndDate);
                parms.Add("@IsCurrent", year.IsCurrent);

                return await con.QuerySingleOrDefaultAsync<int>(
                    "sp_CreateAcademicYear", 
                    parms, 
                    commandType: CommandType.StoredProcedure);
            }
        }

        public async Task<bool> SetCurrentAcademicYearAsync(int academicYearId)
        {
            using (IDbConnection con = connection())
            {
                DynamicParameters parms = new DynamicParameters();
                parms.Add("@AcademicYearId", academicYearId);

                int rows = await con.QuerySingleOrDefaultAsync<int>(
                    "sp_SetCurrentAcademicYear", 
                    parms, 
                    commandType: CommandType.StoredProcedure);

                return rows > 0;
            }
        }
    }
}
