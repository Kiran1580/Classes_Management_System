using System;
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
    public class StudentRepository : IStudentRepository
    {
        private readonly IDbConnectionFactory _connectionFactory;

        public StudentRepository(IDbConnectionFactory connectionFactory)
        {
            _connectionFactory = connectionFactory;
        }

        private IDbConnection CreateConnection() => _connectionFactory.CreateConnection();

        public async Task<(IEnumerable<Student> Students, int TotalCount)> GetPagedStudentsAsync(
            string? searchTerm,
            int pageNumber,
            int pageSize,
            string? sortColumn,
            string? sortDirection,
            int? courseId,
            int? batchId,
            string? statusFilter)
        {
            using (IDbConnection con = CreateConnection())
            {
                var parms = new DynamicParameters();
                parms.Add("@SearchTerm", string.IsNullOrWhiteSpace(searchTerm) ? null : searchTerm.Trim());
                parms.Add("@PageNumber", pageNumber < 1 ? 1 : pageNumber);
                parms.Add("@PageSize", pageSize < 1 ? 6 : pageSize);
                parms.Add("@SortColumn", string.IsNullOrWhiteSpace(sortColumn) ? "StudentId" : sortColumn.Trim());
                parms.Add("@SortDirection", string.IsNullOrWhiteSpace(sortDirection) ? "DESC" : sortDirection.Trim());
                parms.Add("@CourseId", courseId);
                parms.Add("@BatchId", batchId);
                parms.Add("@StatusFilter", string.IsNullOrWhiteSpace(statusFilter) ? null : statusFilter.Trim());
                parms.Add("@TotalCount", dbType: DbType.Int32, direction: ParameterDirection.Output);

                var students = await con.QueryAsync<Student>(
                    "sp_GetPagedStudents",
                    parms,
                    commandType: CommandType.StoredProcedure);

                int totalCount = parms.Get<int>("@TotalCount");
                return (students, totalCount);
            }
        }

        public async Task<Student?> GetStudentByIdAsync(int studentId)
        {
            using (IDbConnection con = CreateConnection())
            {
                var parms = new DynamicParameters();
                parms.Add("@StudentId", studentId);

                return await con.QueryFirstOrDefaultAsync<Student>(
                    "sp_GetStudentById",
                    parms,
                    commandType: CommandType.StoredProcedure);
            }
        }

        public async Task<Student?> GetStudentByUserIdAsync(int userId)
        {
            using (IDbConnection con = CreateConnection())
            {
                var parms = new DynamicParameters();
                parms.Add("@UserId", userId);

                return await con.QueryFirstOrDefaultAsync<Student>(
                    "sp_GetStudentByUserId",
                    parms,
                    commandType: CommandType.StoredProcedure);
            }
        }

        public async Task<int> UpdateStudentProfileAsync(int studentId, string? gender, DateTime? dateOfBirth, string? address, string? profileImage)
        {
            using (IDbConnection con = CreateConnection())
            {
                var parms = new DynamicParameters();
                parms.Add("@StudentId", studentId);
                parms.Add("@Gender", gender);
                parms.Add("@DateOfBirth", dateOfBirth);
                parms.Add("@Address", string.IsNullOrWhiteSpace(address) ? null : address.Trim());
                parms.Add("@ProfileImage", profileImage);

                return await con.QuerySingleOrDefaultAsync<int>(
                    "sp_UpdateStudentProfile",
                    parms,
                    commandType: CommandType.StoredProcedure);
            }
        }

        public async Task<int> CreateStudentAdmissionAsync(Student student, int? batchId, DateTime? enrollmentDate)
        {
            using (IDbConnection con = CreateConnection())
            {
                var parms = new DynamicParameters();
                parms.Add("@AdmissionNo", string.IsNullOrWhiteSpace(student.AdmissionNo) ? null : student.AdmissionNo.Trim());
                parms.Add("@FirstName", student.FirstName.Trim());
                parms.Add("@LastName", student.LastName.Trim());
                parms.Add("@Gender", student.Gender);
                parms.Add("@DateOfBirth", student.DateOfBirth);
                parms.Add("@Mobile", string.IsNullOrWhiteSpace(student.Mobile) ? null : student.Mobile.Trim());
                parms.Add("@Email", string.IsNullOrWhiteSpace(student.Email) ? null : student.Email.Trim());
                parms.Add("@Address", string.IsNullOrWhiteSpace(student.Address) ? null : student.Address.Trim());
                parms.Add("@ParentName", string.IsNullOrWhiteSpace(student.ParentName) ? null : student.ParentName.Trim());
                parms.Add("@ParentMobile", string.IsNullOrWhiteSpace(student.ParentMobile) ? null : student.ParentMobile.Trim());
                parms.Add("@AdmissionDate", student.AdmissionDate);
                parms.Add("@ProfileImage", student.ProfileImage);
                parms.Add("@BatchId", batchId);
                parms.Add("@EnrollmentDate", enrollmentDate ?? student.AdmissionDate);

                return await con.QuerySingleOrDefaultAsync<int>(
                    "sp_CreateStudentAdmission",
                    parms,
                    commandType: CommandType.StoredProcedure);
            }
        }

        public async Task<int> UpdateStudentAsync(Student student, int? batchId)
        {
            using (IDbConnection con = CreateConnection())
            {
                var parms = new DynamicParameters();
                parms.Add("@StudentId", student.StudentId);
                parms.Add("@AdmissionNo", student.AdmissionNo.Trim());
                parms.Add("@FirstName", student.FirstName.Trim());
                parms.Add("@LastName", student.LastName.Trim());
                parms.Add("@Gender", student.Gender);
                parms.Add("@DateOfBirth", student.DateOfBirth);
                parms.Add("@Mobile", string.IsNullOrWhiteSpace(student.Mobile) ? null : student.Mobile.Trim());
                parms.Add("@Email", string.IsNullOrWhiteSpace(student.Email) ? null : student.Email.Trim());
                parms.Add("@Address", string.IsNullOrWhiteSpace(student.Address) ? null : student.Address.Trim());
                parms.Add("@ParentName", string.IsNullOrWhiteSpace(student.ParentName) ? null : student.ParentName.Trim());
                parms.Add("@ParentMobile", string.IsNullOrWhiteSpace(student.ParentMobile) ? null : student.ParentMobile.Trim());
                parms.Add("@AdmissionDate", student.AdmissionDate);
                parms.Add("@ProfileImage", student.ProfileImage);
                parms.Add("@IsActive", student.IsActive);
                parms.Add("@BatchId", batchId);

                return await con.QuerySingleOrDefaultAsync<int>(
                    "sp_UpdateStudent",
                    parms,
                    commandType: CommandType.StoredProcedure);
            }
        }

        public async Task<int> DeleteOrDeactivateStudentAsync(int studentId)
        {
            using (IDbConnection con = CreateConnection())
            {
                var parms = new DynamicParameters();
                parms.Add("@StudentId", studentId);

                return await con.QuerySingleOrDefaultAsync<int>(
                    "sp_DeleteOrDeactivateStudent",
                    parms,
                    commandType: CommandType.StoredProcedure);
            }
        }

        public async Task<(int Total, int Active, int Inactive, int Enrolled, int NewThisMonth)> GetStudentStatsAsync()
        {
            using (IDbConnection con = CreateConnection())
            {
                var row = await con.QueryFirstOrDefaultAsync<dynamic>(
                    "sp_GetStudentStats",
                    commandType: CommandType.StoredProcedure);

                if (row == null) return (0, 0, 0, 0, 0);

                return (
                    (int)(row.TotalStudents ?? 0),
                    (int)(row.ActiveStudents ?? 0),
                    (int)(row.InactiveStudents ?? 0),
                    (int)(row.EnrolledStudents ?? 0),
                    (int)(row.NewAdmissionsThisMonth ?? 0)
                );
            }
        }

        public async Task<string> GetNextAdmissionNumberAsync(string prefix = "ADM")
        {
            using (IDbConnection con = CreateConnection())
            {
                var parms = new DynamicParameters();
                parms.Add("@Prefix", prefix);
                parms.Add("@NextAdmissionNo", dbType: DbType.String, size: 50, direction: ParameterDirection.Output);

                await con.ExecuteAsync(
                    "sp_GetNextAdmissionNumber",
                    parms,
                    commandType: CommandType.StoredProcedure);

                return parms.Get<string>("@NextAdmissionNo") ?? $"{prefix}-{DateTime.Now.Year}-0001";
            }
        }

        public async Task<IEnumerable<Batch>> GetBatchesByCourseAsync(int courseId)
        {
            using (IDbConnection con = CreateConnection())
            {
                var parms = new DynamicParameters();
                parms.Add("@CourseId", courseId);

                return await con.QueryAsync<Batch>(
                    "sp_GetBatchesByCourse",
                    parms,
                    commandType: CommandType.StoredProcedure);
            }
        }

        public async Task<(Student? StudentInfo, IEnumerable<StudentEnrolledBatch> Batches, IEnumerable<StudentBatchSubject> Subjects)> GetStudentCoursesAndBatchesAsync(int? userId = null, int? studentId = null)
        {
            using (IDbConnection con = CreateConnection())
            {
                var parms = new DynamicParameters();
                parms.Add("@UserId", userId);
                parms.Add("@StudentId", studentId);

                using (var multi = await con.QueryMultipleAsync(
                    "sp_GetStudentCoursesAndBatches",
                    parms,
                    commandType: CommandType.StoredProcedure))
                {
                    var studentInfo = await multi.ReadFirstOrDefaultAsync<Student>();
                    var batches = (await multi.ReadAsync<StudentEnrolledBatch>()) ?? Enumerable.Empty<StudentEnrolledBatch>();
                    var subjects = (await multi.ReadAsync<StudentBatchSubject>()) ?? Enumerable.Empty<StudentBatchSubject>();

                    return (studentInfo, batches, subjects);
                }
            }
        }
    }
}
