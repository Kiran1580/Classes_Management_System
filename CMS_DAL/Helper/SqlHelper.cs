using System;
using System.Collections.Generic;
using System.Data;
using System.Threading.Tasks;
using CMS_DAL.Connection;
using Microsoft.Data.SqlClient;

namespace CMS_DAL.Helper
{
    public class SqlHelper
    {
        private readonly IDbConnectionFactory _connectionFactory;

        public SqlHelper(IDbConnectionFactory connectionFactory)
        {
            _connectionFactory = connectionFactory;
        }

        public async Task<int> ExecuteNonQueryAsync(string query, SqlParameter[]? parameters = null, CommandType commandType = CommandType.Text)
        {
            using var connection = _connectionFactory.CreateSqlConnection();
            using var command = new SqlCommand(query, connection) { CommandType = commandType };

            if (parameters != null && parameters.Length > 0)
            {
                command.Parameters.AddRange(parameters);
            }

            await connection.OpenAsync();
            return await command.ExecuteNonQueryAsync();
        }

        public async Task<object?> ExecuteScalarAsync(string query, SqlParameter[]? parameters = null, CommandType commandType = CommandType.Text)
        {
            using var connection = _connectionFactory.CreateSqlConnection();
            using var command = new SqlCommand(query, connection) { CommandType = commandType };

            if (parameters != null && parameters.Length > 0)
            {
                command.Parameters.AddRange(parameters);
            }

            await connection.OpenAsync();
            return await command.ExecuteScalarAsync();
        }

        public async Task<DataTable> ExecuteDataTableAsync(string query, SqlParameter[]? parameters = null, CommandType commandType = CommandType.Text)
        {
            using var connection = _connectionFactory.CreateSqlConnection();
            using var command = new SqlCommand(query, connection) { CommandType = commandType };

            if (parameters != null && parameters.Length > 0)
            {
                command.Parameters.AddRange(parameters);
            }

            await connection.OpenAsync();
            using var reader = await command.ExecuteReaderAsync();
            var dataTable = new DataTable();
            dataTable.Load(reader);
            return dataTable;
        }

        public async Task<List<T>> ExecuteQueryAsync<T>(string query, Func<SqlDataReader, T> map, SqlParameter[]? parameters = null, CommandType commandType = CommandType.Text)
        {
            var results = new List<T>();
            using var connection = _connectionFactory.CreateSqlConnection();
            using var command = new SqlCommand(query, connection) { CommandType = commandType };

            if (parameters != null && parameters.Length > 0)
            {
                command.Parameters.AddRange(parameters);
            }

            await connection.OpenAsync();
            using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                results.Add(map(reader));
            }

            return results;
        }

        public async Task<T?> ExecuteSingleAsync<T>(string query, Func<SqlDataReader, T> map, SqlParameter[]? parameters = null, CommandType commandType = CommandType.Text) where T : class
        {
            using var connection = _connectionFactory.CreateSqlConnection();
            using var command = new SqlCommand(query, connection) { CommandType = commandType };

            if (parameters != null && parameters.Length > 0)
            {
                command.Parameters.AddRange(parameters);
            }

            await connection.OpenAsync();
            using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return map(reader);
            }

            return null;
        }
    }
}
