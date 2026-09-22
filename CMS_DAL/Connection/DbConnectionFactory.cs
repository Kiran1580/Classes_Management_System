using System.Data;
using Microsoft.Data.SqlClient;

namespace CMS_DAL.Connection
{
    public interface IDbConnectionFactory
    {
        IDbConnection CreateConnection();
        SqlConnection CreateSqlConnection();
    }

    public class DbConnectionFactory : IDbConnectionFactory
    {
        private readonly string _connectionString;

        public DbConnectionFactory(string connectionString)
        {
            _connectionString = connectionString ?? throw new ArgumentNullException(nameof(connectionString));
        }

        public IDbConnection CreateConnection()
        {
            return new SqlConnection(_connectionString);
        }

        public SqlConnection CreateSqlConnection()
        {
            return new SqlConnection(_connectionString);
        }
    }
}
