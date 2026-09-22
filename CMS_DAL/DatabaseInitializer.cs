using System;
using System.Data;
using System.IO;
using System.Threading.Tasks;
using CMS_DAL.Connection;
using Microsoft.Data.SqlClient;

namespace CMS_DAL
{
    public class DatabaseInitializer
    {
        private readonly IDbConnectionFactory _connectionFactory;

        public DatabaseInitializer(IDbConnectionFactory connectionFactory)
        {
            _connectionFactory = connectionFactory;
        }

        public async Task InitializeAsync()
        {
            using var connection = _connectionFactory.CreateSqlConnection();
            await connection.OpenAsync();

            // Check if Roles table exists
            using (var checkCmd = new SqlCommand("SELECT COUNT(1) FROM sys.tables WHERE name = 'Roles'", connection))
            {
                var tableExists = Convert.ToInt32(await checkCmd.ExecuteScalarAsync()) > 0;
                if (!tableExists)
                {
                    // Fallback to run script if needed
                }
            }

            // Ensure baseline Roles exist
            string[] roles = { "Admin", "Teacher", "Student" };
            foreach (var role in roles)
            {
                using var roleCmd = new SqlCommand(@"
                    IF NOT EXISTS (SELECT 1 FROM Roles WHERE RoleName = @RoleName)
                    BEGIN
                        INSERT INTO Roles (RoleName) VALUES (@RoleName);
                    END", connection);
                roleCmd.Parameters.Add(new SqlParameter("@RoleName", SqlDbType.NVarChar, 50) { Value = role });
                await roleCmd.ExecuteNonQueryAsync();
            }

            // Ensure Admin User exists
            using (var adminCmd = new SqlCommand("SELECT COUNT(1) FROM Users WHERE Email = 'admin@cms.com'", connection))
            {
                var adminExists = Convert.ToInt32(await adminCmd.ExecuteScalarAsync()) > 0;
                if (!adminExists)
                {
                    var adminHash = BCrypt.Net.BCrypt.HashPassword("Admin@123");
                    using var insertCmd = new SqlCommand(@"
                        DECLARE @AdminRoleId INT = (SELECT RoleId FROM Roles WHERE RoleName = 'Admin');
                        INSERT INTO Users (FullName, Email, Mobile, PasswordHash, RoleId, IsActive, CreatedAt)
                        VALUES ('Super Administrator', 'admin@cms.com', '9876543210', @PasswordHash, @AdminRoleId, 1, GETDATE());", connection);
                    insertCmd.Parameters.Add(new SqlParameter("@PasswordHash", SqlDbType.NVarChar, 255) { Value = adminHash });
                    await insertCmd.ExecuteNonQueryAsync();
                }
            }

            // Ensure Sample Teacher User exists
            using (var teacherCmd = new SqlCommand("SELECT COUNT(1) FROM Users WHERE Email = 'teacher@cms.com'", connection))
            {
                var teacherExists = Convert.ToInt32(await teacherCmd.ExecuteScalarAsync()) > 0;
                if (!teacherExists)
                {
                    var teacherHash = BCrypt.Net.BCrypt.HashPassword("Teacher@123");
                    using var insertCmd = new SqlCommand(@"
                        DECLARE @TeacherRoleId INT = (SELECT RoleId FROM Roles WHERE RoleName = 'Teacher');
                        INSERT INTO Users (FullName, Email, Mobile, PasswordHash, RoleId, IsActive, CreatedAt)
                        VALUES ('Amit Sharma', 'teacher@cms.com', '9876543211', @PasswordHash, @TeacherRoleId, 1, GETDATE());
                        DECLARE @NewUserId INT = SCOPE_IDENTITY();

                        INSERT INTO Teachers (UserId, EmployeeCode, FirstName, LastName, Mobile, Email, Qualification, JoiningDate, IsActive)
                        VALUES (@NewUserId, 'EMP001', 'Amit', 'Sharma', '9876543211', 'teacher@cms.com', 'M.Sc. Physics (IIT Bombay)', '2023-06-01', 1);", connection);
                    insertCmd.Parameters.Add(new SqlParameter("@PasswordHash", SqlDbType.NVarChar, 255) { Value = teacherHash });
                    await insertCmd.ExecuteNonQueryAsync();
                }
            }

            // Ensure Sample Student User exists
            using (var studentCmd = new SqlCommand("SELECT COUNT(1) FROM Users WHERE Email = 'student@cms.com'", connection))
            {
                var studentExists = Convert.ToInt32(await studentCmd.ExecuteScalarAsync()) > 0;
                if (!studentExists)
                {
                    var studentHash = BCrypt.Net.BCrypt.HashPassword("Student@123");
                    using var insertCmd = new SqlCommand(@"
                        DECLARE @StudentRoleId INT = (SELECT RoleId FROM Roles WHERE RoleName = 'Student');
                        INSERT INTO Users (FullName, Email, Mobile, PasswordHash, RoleId, IsActive, CreatedAt)
                        VALUES ('Rahul Verma', 'student@cms.com', '9876543212', @PasswordHash, @StudentRoleId, 1, GETDATE());
                        DECLARE @NewStudentUserId INT = SCOPE_IDENTITY();

                        INSERT INTO Students (UserId, AdmissionNo, FirstName, LastName, Gender, DateOfBirth, Mobile, Email, Address, ParentName, ParentMobile, AdmissionDate, IsActive)
                        VALUES (@NewStudentUserId, 'ADM2025001', 'Rahul', 'Verma', 'Male', '2008-05-14', '9876543212', 'student@cms.com', '12 Civil Lines, North City', 'Suresh Verma', '9876543299', CAST(GETDATE() AS DATE), 1);", connection);
                    insertCmd.Parameters.Add(new SqlParameter("@PasswordHash", SqlDbType.NVarChar, 255) { Value = studentHash });
                    await insertCmd.ExecuteNonQueryAsync();
                }
            }
        }
    }
}
