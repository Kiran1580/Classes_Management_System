using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Threading.Tasks;
using CMS_DAL.Connection;
using CMS_DAL.Models;
using CMS_DAL.Repositories.Interfaces;
using Dapper;

namespace CMS_DAL.Repositories.Implementations
{
    public class CourseRepository : ICourseRepository
    {
        private readonly IDbConnectionFactory _connectionFactory;

        public CourseRepository(IDbConnectionFactory connectionFactory)
        {
            _connectionFactory = connectionFactory;
        }

        private IDbConnection connection() => _connectionFactory.CreateConnection();

        public async Task<IEnumerable<Course>> GetAllCoursesAsync()
        {
            using (IDbConnection con = connection())
            {
                return await con.QueryAsync<Course>(
                    "sp_GetAllCourses",
                    commandType: CommandType.StoredProcedure);
            }
        }

        public async Task<(IEnumerable<Course> Courses, int TotalCount)> GetPagedCoursesAsync(string? searchTerm, int pageNumber, int pageSize, string sortColumn = "Id", string sortDirection = "DESC")
        {
            using (IDbConnection con = connection())
            {
                DynamicParameters parms = new DynamicParameters();
                parms.Add("@SearchTerm", string.IsNullOrWhiteSpace(searchTerm) ? null : searchTerm.Trim());
                parms.Add("@PageNumber", pageNumber < 1 ? 1 : pageNumber);
                parms.Add("@PageSize", pageSize < 1 ? 6 : pageSize);
                parms.Add("@SortColumn", string.IsNullOrWhiteSpace(sortColumn) ? "Id" : sortColumn.Trim());
                parms.Add("@SortDirection", string.IsNullOrWhiteSpace(sortDirection) ? "DESC" : sortDirection.Trim());
                parms.Add("@TotalCount", dbType: DbType.Int32, direction: ParameterDirection.Output);

                var courses = await con.QueryAsync<Course>(
                    "sp_GetPagedCourses",
                    parms,
                    commandType: CommandType.StoredProcedure);

                int totalCount = parms.Get<int>("@TotalCount");
                return (courses, totalCount);
            }
        }

        public async Task<Course?> GetCourseByIdAsync(int courseId)
        {
            using (IDbConnection con = connection())
            {
                DynamicParameters parms = new DynamicParameters();
                parms.Add("@CourseId", courseId);

                return await con.QueryFirstOrDefaultAsync<Course>(
                    "sp_GetCourseById",
                    parms,
                    commandType: CommandType.StoredProcedure);
            }
        }

        public async Task<int> CreateCourseAsync(Course course)
        {
            using (IDbConnection con = connection())
            {
                DynamicParameters parms = new DynamicParameters();
                parms.Add("@CourseName", course.CourseName.Trim());
                parms.Add("@Description", course.Description?.Trim());
                parms.Add("@Duration", course.Duration?.Trim());
                parms.Add("@IsActive", course.IsActive);

                return await con.QuerySingleOrDefaultAsync<int>(
                    "sp_CreateCourse",
                    parms,
                    commandType: CommandType.StoredProcedure);
            }
        }

        public async Task<int> UpdateCourseAsync(Course course)
        {
            using (IDbConnection con = connection())
            {
                DynamicParameters parms = new DynamicParameters();
                parms.Add("@CourseId", course.CourseId);
                parms.Add("@CourseName", course.CourseName.Trim());
                parms.Add("@Description", course.Description?.Trim());
                parms.Add("@Duration", course.Duration?.Trim());
                parms.Add("@IsActive", course.IsActive);

                return await con.QuerySingleOrDefaultAsync<int>(
                    "sp_UpdateCourse",
                    parms,
                    commandType: CommandType.StoredProcedure);
            }
        }

        public async Task<int> DeleteCourseAsync(int courseId)
        {
            using (IDbConnection con = connection())
            {
                DynamicParameters parms = new DynamicParameters();
                parms.Add("@CourseId", courseId);

                return await con.QuerySingleOrDefaultAsync<int>(
                    "sp_DeleteCourse",
                    parms,
                    commandType: CommandType.StoredProcedure);
            }
        }

        public async Task<IEnumerable<Subject>> GetAllSubjectsAsync()
        {
            using (IDbConnection con = connection())
            {
                return await con.QueryAsync<Subject>(
                    "sp_GetAllSubjects",
                    commandType: CommandType.StoredProcedure);
            }
        }

        public async Task<(IEnumerable<Subject> Subjects, int TotalCount)> GetPagedSubjectsAsync(string? searchTerm, int pageNumber, int pageSize, string sortColumn = "Id", string sortDirection = "DESC")
        {
            using (IDbConnection con = connection())
            {
                DynamicParameters parms = new DynamicParameters();
                parms.Add("@SearchTerm", string.IsNullOrWhiteSpace(searchTerm) ? null : searchTerm.Trim());
                parms.Add("@PageNumber", pageNumber < 1 ? 1 : pageNumber);
                parms.Add("@PageSize", pageSize < 1 ? 6 : pageSize);
                parms.Add("@SortColumn", string.IsNullOrWhiteSpace(sortColumn) ? "Id" : sortColumn.Trim());
                parms.Add("@SortDirection", string.IsNullOrWhiteSpace(sortDirection) ? "DESC" : sortDirection.Trim());
                parms.Add("@TotalCount", dbType: DbType.Int32, direction: ParameterDirection.Output);

                var subjects = await con.QueryAsync<Subject>(
                    "sp_GetPagedSubjects",
                    parms,
                    commandType: CommandType.StoredProcedure);

                int totalCount = parms.Get<int>("@TotalCount");
                return (subjects, totalCount);
            }
        }

        public async Task<Subject?> GetSubjectByIdAsync(int subjectId)
        {
            using (IDbConnection con = connection())
            {
                DynamicParameters parms = new DynamicParameters();
                parms.Add("@SubjectId", subjectId);

                return await con.QueryFirstOrDefaultAsync<Subject>(
                    "sp_GetSubjectById",
                    parms,
                    commandType: CommandType.StoredProcedure);
            }
        }

        public async Task<int> CreateSubjectAsync(Subject subject)
        {
            using (IDbConnection con = connection())
            {
                DynamicParameters parms = new DynamicParameters();
                parms.Add("@SubjectName", subject.SubjectName.Trim());
                parms.Add("@Description", subject.Description?.Trim());
                parms.Add("@IsActive", subject.IsActive);

                return await con.QuerySingleOrDefaultAsync<int>(
                    "sp_CreateSubject",
                    parms,
                    commandType: CommandType.StoredProcedure);
            }
        }

        public async Task<int> UpdateSubjectAsync(Subject subject)
        {
            using (IDbConnection con = connection())
            {
                DynamicParameters parms = new DynamicParameters();
                parms.Add("@SubjectId", subject.SubjectId);
                parms.Add("@SubjectName", subject.SubjectName.Trim());
                parms.Add("@Description", subject.Description?.Trim());
                parms.Add("@IsActive", subject.IsActive);

                return await con.QuerySingleOrDefaultAsync<int>(
                    "sp_UpdateSubject",
                    parms,
                    commandType: CommandType.StoredProcedure);
            }
        }

        public async Task<int> DeleteSubjectAsync(int subjectId)
        {
            using (IDbConnection con = connection())
            {
                DynamicParameters parms = new DynamicParameters();
                parms.Add("@SubjectId", subjectId);

                return await con.QuerySingleOrDefaultAsync<int>(
                    "sp_DeleteSubject",
                    parms,
                    commandType: CommandType.StoredProcedure);
            }
        }

        public async Task<IEnumerable<Subject>> GetSubjectsByCourseIdAsync(int courseId)
        {
            using (IDbConnection con = connection())
            {
                DynamicParameters parms = new DynamicParameters();
                parms.Add("@CourseId", courseId);

                return await con.QueryAsync<Subject>(
                    "sp_GetSubjectsByCourseId",
                    parms,
                    commandType: CommandType.StoredProcedure);
            }
        }

        public async Task<bool> AssignSubjectsToCourseAsync(int courseId, IEnumerable<int> subjectIds)
        {
            using (IDbConnection con = connection())
            {
                string idsCsv = (subjectIds != null && subjectIds.Any())
                    ? string.Join(",", subjectIds)
                    : string.Empty;

                DynamicParameters parms = new DynamicParameters();
                parms.Add("@CourseId", courseId);
                parms.Add("@SubjectIds", idsCsv);

                int result = await con.QuerySingleOrDefaultAsync<int>(
                    "sp_AssignSubjectsToCourse",
                    parms,
                    commandType: CommandType.StoredProcedure);

                return result > 0;
            }
        }
    }
}
