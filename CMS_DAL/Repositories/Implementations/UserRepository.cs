using System.Collections.Generic;
using System.Data;
using System.Threading.Tasks;
using CMS_DAL.Connection;
using CMS_DAL.Models;
using CMS_DAL.Repositories.Interfaces;
using Dapper;

namespace CMS_DAL.Repositories.Implementations
{
    public class UserRepository : IUserRepository
    {
        private readonly IDbConnectionFactory _connectionFactory;

        public UserRepository(IDbConnectionFactory connectionFactory)
        {
            _connectionFactory = connectionFactory;
        }

        private IDbConnection connection() => _connectionFactory.CreateConnection();

        public async Task<User?> GetByEmailAsync(string email)
        {
            using (IDbConnection con = connection())
            {
                DynamicParameters parms = new DynamicParameters();
                parms.Add("@Email", email.Trim());

                return await con.QueryFirstOrDefaultAsync<User>(
                    "sp_GetUserByEmail", 
                    parms, 
                    commandType: CommandType.StoredProcedure);
            }
        }

        public async Task<User?> GetByIdAsync(int userId)
        {
            using (IDbConnection con = connection())
            {
                DynamicParameters parms = new DynamicParameters();
                parms.Add("@UserId", userId);

                return await con.QueryFirstOrDefaultAsync<User>(
                    "sp_GetUserById", 
                    parms, 
                    commandType: CommandType.StoredProcedure);
            }
        }

        public async Task<int> CreateUserAsync(User user)
        {
            using (IDbConnection con = connection())
            {
                DynamicParameters parms = new DynamicParameters();
                parms.Add("@FullName", user.FullName);
                parms.Add("@Email", user.Email.Trim());
                parms.Add("@Mobile", user.Mobile);
                parms.Add("@PasswordHash", user.PasswordHash);
                parms.Add("@RoleId", user.RoleId);
                parms.Add("@IsActive", user.IsActive);

                return await con.QuerySingleOrDefaultAsync<int>(
                    "sp_CreateUser", 
                    parms, 
                    commandType: CommandType.StoredProcedure);
            }
        }

        public async Task<bool> UpdatePasswordAsync(int userId, string passwordHash)
        {
            using (IDbConnection con = connection())
            {
                DynamicParameters parms = new DynamicParameters();
                parms.Add("@UserId", userId);
                parms.Add("@PasswordHash", passwordHash);

                int rows = await con.QuerySingleOrDefaultAsync<int>(
                    "sp_UpdateUserPassword", 
                    parms, 
                    commandType: CommandType.StoredProcedure);

                return rows > 0;
            }
        }

        public async Task<bool> EmailExistsAsync(string email)
        {
            using (IDbConnection con = connection())
            {
                DynamicParameters parms = new DynamicParameters();
                parms.Add("@Email", email.Trim());

                int count = await con.QuerySingleOrDefaultAsync<int>(
                    "sp_CheckEmailExists", 
                    parms, 
                    commandType: CommandType.StoredProcedure);

                return count > 0;
            }
        }

        public async Task<IEnumerable<User>> GetAllUsersByRoleAsync(string roleName)
        {
            using (IDbConnection con = connection())
            {
                DynamicParameters parms = new DynamicParameters();
                parms.Add("@RoleName", roleName);

                return await con.QueryAsync<User>(
                    "sp_GetUsersByRole", 
                    parms, 
                    commandType: CommandType.StoredProcedure);
            }
        }
    }
}
