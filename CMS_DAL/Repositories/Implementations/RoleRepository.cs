using System.Collections.Generic;
using System.Data;
using System.Threading.Tasks;
using CMS_DAL.Connection;
using CMS_DAL.Models;
using CMS_DAL.Repositories.Interfaces;
using Dapper;

namespace CMS_DAL.Repositories.Implementations
{
    public class RoleRepository : IRoleRepository
    {
        private readonly IDbConnectionFactory _connectionFactory;

        public RoleRepository(IDbConnectionFactory connectionFactory)
        {
            _connectionFactory = connectionFactory;
        }

        private IDbConnection connection() => _connectionFactory.CreateConnection();

        public async Task<IEnumerable<Role>> GetAllRolesAsync()
        {
            using (IDbConnection con = connection())
            {
                return await con.QueryAsync<Role>(
                    "sp_GetAllRoles", 
                    commandType: CommandType.StoredProcedure);
            }
        }

        public async Task<Role?> GetByIdAsync(int roleId)
        {
            using (IDbConnection con = connection())
            {
                DynamicParameters parms = new DynamicParameters();
                parms.Add("@RoleId", roleId);

                return await con.QueryFirstOrDefaultAsync<Role>(
                    "sp_GetRoleById", 
                    parms, 
                    commandType: CommandType.StoredProcedure);
            }
        }

        public async Task<Role?> GetByNameAsync(string roleName)
        {
            using (IDbConnection con = connection())
            {
                DynamicParameters parms = new DynamicParameters();
                parms.Add("@RoleName", roleName.Trim());

                return await con.QueryFirstOrDefaultAsync<Role>(
                    "sp_GetRoleByName", 
                    parms, 
                    commandType: CommandType.StoredProcedure);
            }
        }
    }
}
