using System;
using System.Collections.Generic;
using System.Data;
using System.Threading.Tasks;
using CMS_DAL.Helper;
using CMS_DAL.Models;
using CMS_DAL.Repositories.Interfaces;
using Microsoft.Data.SqlClient;

namespace CMS_DAL.Repositories.Implementations
{
    public class AcademicYearRepository : IAcademicYearRepository
    {
        private readonly SqlHelper _sqlHelper;

        public AcademicYearRepository(SqlHelper sqlHelper)
        {
            _sqlHelper = sqlHelper;
        }

        public async Task<AcademicYear?> GetCurrentAcademicYearAsync()
        {
            return await _sqlHelper.ExecuteSingleAsync("sp_GetCurrentAcademicYear", MapAcademicYear, null, CommandType.StoredProcedure);
        }

        public async Task<IEnumerable<AcademicYear>> GetAllAsync()
        {
            return await _sqlHelper.ExecuteQueryAsync("sp_GetAllAcademicYears", MapAcademicYear, null, CommandType.StoredProcedure);
        }

        public async Task<int> CreateAsync(AcademicYear year)
        {
            var parameters = new[]
            {
                new SqlParameter("@YearName", SqlDbType.NVarChar, 50) { Value = year.YearName },
                new SqlParameter("@StartDate", SqlDbType.Date) { Value = year.StartDate },
                new SqlParameter("@EndDate", SqlDbType.Date) { Value = year.EndDate },
                new SqlParameter("@IsCurrent", SqlDbType.Bit) { Value = year.IsCurrent }
            };

            var result = await _sqlHelper.ExecuteScalarAsync("sp_CreateAcademicYear", parameters, CommandType.StoredProcedure);
            return result != null && result != DBNull.Value ? Convert.ToInt32(result) : 0;
        }

        public async Task<bool> SetCurrentAcademicYearAsync(int academicYearId)
        {
            var parameters = new[]
            {
                new SqlParameter("@AcademicYearId", SqlDbType.Int) { Value = academicYearId }
            };

            var result = await _sqlHelper.ExecuteScalarAsync("sp_SetCurrentAcademicYear", parameters, CommandType.StoredProcedure);
            return result != null && Convert.ToInt32(result) > 0;
        }

        private static AcademicYear MapAcademicYear(SqlDataReader reader)
        {
            return new AcademicYear
            {
                AcademicYearId = Convert.ToInt32(reader["AcademicYearId"]),
                YearName = reader["YearName"].ToString() ?? string.Empty,
                StartDate = Convert.ToDateTime(reader["StartDate"]),
                EndDate = Convert.ToDateTime(reader["EndDate"]),
                IsCurrent = Convert.ToBoolean(reader["IsCurrent"]),
                CreatedAt = Convert.ToDateTime(reader["CreatedAt"])
            };
        }
    }
}
