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
    public class RoleRepository : IRoleRepository
    {
        private readonly SqlHelper _sqlHelper;

        public RoleRepository(SqlHelper sqlHelper)
        {
            _sqlHelper = sqlHelper;
        }

        public async Task<IEnumerable<Role>> GetAllRolesAsync()
        {
            return await _sqlHelper.ExecuteQueryAsync("sp_GetAllRoles", MapRole, null, CommandType.StoredProcedure);
        }

        public async Task<Role?> GetByIdAsync(int roleId)
        {
            var parameters = new[] { new SqlParameter("@RoleId", SqlDbType.Int) { Value = roleId } };
            return await _sqlHelper.ExecuteSingleAsync("sp_GetRoleById", MapRole, parameters, CommandType.StoredProcedure);
        }

        public async Task<Role?> GetByNameAsync(string roleName)
        {
            var parameters = new[] { new SqlParameter("@RoleName", SqlDbType.NVarChar, 50) { Value = roleName.Trim() } };
            return await _sqlHelper.ExecuteSingleAsync("sp_GetRoleByName", MapRole, parameters, CommandType.StoredProcedure);
        }

        private static Role MapRole(SqlDataReader reader)
        {
            return new Role
            {
                RoleId = Convert.ToInt32(reader["RoleId"]),
                RoleName = reader["RoleName"].ToString() ?? string.Empty
            };
        }
    }
}
