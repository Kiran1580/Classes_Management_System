using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using CMS_DAL.Models;

namespace CMS_DAL.Repositories.Interfaces
{
    public interface IStudentRepository
    {
        Task<(IEnumerable<Student> Students, int TotalCount)> GetPagedStudentsAsync(
            string? searchTerm,
            int pageNumber,
            int pageSize,
            string? sortColumn,
            string? sortDirection,
            int? courseId,
            int? batchId,
            string? statusFilter);

        Task<Student?> GetStudentByIdAsync(int studentId);

        Task<Student?> GetStudentByUserIdAsync(int userId);

        Task<int> UpdateStudentProfileAsync(int studentId, string? gender, DateTime? dateOfBirth, string? address, string? profileImage);

        Task<int> CreateStudentAdmissionAsync(Student student, int? batchId, DateTime? enrollmentDate);

        Task<int> UpdateStudentAsync(Student student, int? batchId);

        Task<int> DeleteOrDeactivateStudentAsync(int studentId);

        Task<(int Total, int Active, int Inactive, int Enrolled, int NewThisMonth)> GetStudentStatsAsync();

        Task<string> GetNextAdmissionNumberAsync(string prefix = "ADM");

        Task<IEnumerable<Batch>> GetBatchesByCourseAsync(int courseId);

        Task<(Student? StudentInfo, IEnumerable<StudentEnrolledBatch> Batches, IEnumerable<StudentBatchSubject> Subjects)> GetStudentCoursesAndBatchesAsync(int? userId = null, int? studentId = null);
    }
}
