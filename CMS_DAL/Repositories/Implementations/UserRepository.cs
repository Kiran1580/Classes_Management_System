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
    public class UserRepository : IUserRepository
    {
        private readonly SqlHelper _sqlHelper;

        public UserRepository(SqlHelper sqlHelper)
        {
            _sqlHelper = sqlHelper;
        }

        public async Task<User?> GetByEmailAsync(string email)
        {
            var parameters = new[]
            {
                new SqlParameter("@Email", SqlDbType.NVarChar, 100) { Value = email.Trim() }
            };

            return await _sqlHelper.ExecuteSingleAsync("sp_GetUserByEmail", MapUser, parameters, CommandType.StoredProcedure);
        }

        public async Task<User?> GetByIdAsync(int userId)
        {
            var parameters = new[]
            {
                new SqlParameter("@UserId", SqlDbType.Int) { Value = userId }
            };

            return await _sqlHelper.ExecuteSingleAsync("sp_GetUserById", MapUser, parameters, CommandType.StoredProcedure);
        }

        public async Task<int> CreateUserAsync(User user)
        {
            var parameters = new[]
            {
                new SqlParameter("@FullName", SqlDbType.NVarChar, 100) { Value = user.FullName },
                new SqlParameter("@Email", SqlDbType.NVarChar, 100) { Value = user.Email.Trim() },
                new SqlParameter("@Mobile", SqlDbType.NVarChar, 20) { Value = (object?)user.Mobile ?? DBNull.Value },
                new SqlParameter("@PasswordHash", SqlDbType.NVarChar, 255) { Value = user.PasswordHash },
                new SqlParameter("@RoleId", SqlDbType.Int) { Value = user.RoleId },
                new SqlParameter("@IsActive", SqlDbType.Bit) { Value = user.IsActive }
            };

            var result = await _sqlHelper.ExecuteScalarAsync("sp_CreateUser", parameters, CommandType.StoredProcedure);
            return result != null && result != DBNull.Value ? Convert.ToInt32(result) : 0;
        }

        public async Task<bool> UpdatePasswordAsync(int userId, string passwordHash)
        {
            var parameters = new[]
            {
                new SqlParameter("@UserId", SqlDbType.Int) { Value = userId },
                new SqlParameter("@PasswordHash", SqlDbType.NVarChar, 255) { Value = passwordHash }
            };

            var result = await _sqlHelper.ExecuteScalarAsync("sp_UpdateUserPassword", parameters, CommandType.StoredProcedure);
            return result != null && Convert.ToInt32(result) > 0;
        }

        public async Task<bool> EmailExistsAsync(string email)
        {
            var parameters = new[]
            {
                new SqlParameter("@Email", SqlDbType.NVarChar, 100) { Value = email.Trim() }
            };

            var result = await _sqlHelper.ExecuteScalarAsync("sp_CheckEmailExists", parameters, CommandType.StoredProcedure);
            return result != null && Convert.ToInt32(result) > 0;
        }

        public async Task<IEnumerable<User>> GetAllUsersByRoleAsync(string roleName)
        {
            var parameters = new[]
            {
                new SqlParameter("@RoleName", SqlDbType.NVarChar, 50) { Value = roleName }
            };

            return await _sqlHelper.ExecuteQueryAsync("sp_GetUsersByRole", MapUser, parameters, CommandType.StoredProcedure);
        }

        private static User MapUser(SqlDataReader reader)
        {
            return new User
            {
                UserId = Convert.ToInt32(reader["UserId"]),
                FullName = reader["FullName"].ToString() ?? string.Empty,
                Email = reader["Email"].ToString() ?? string.Empty,
                Mobile = reader["Mobile"] == DBNull.Value ? null : reader["Mobile"].ToString(),
                PasswordHash = reader["PasswordHash"].ToString() ?? string.Empty,
                RoleId = Convert.ToInt32(reader["RoleId"]),
                RoleName = reader["RoleName"].ToString() ?? string.Empty,
                IsActive = Convert.ToBoolean(reader["IsActive"]),
                CreatedAt = Convert.ToDateTime(reader["CreatedAt"]),
                UpdatedAt = reader["UpdatedAt"] == DBNull.Value ? null : Convert.ToDateTime(reader["UpdatedAt"])
            };
        }
    }
}
