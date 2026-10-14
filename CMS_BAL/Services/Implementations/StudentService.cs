using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using CMS_BAL.Services.Interfaces;
using CMS_BAL.ViewModels;
using CMS_DAL.Models;
using CMS_DAL.Repositories.Interfaces;

namespace CMS_BAL.Services.Implementations
{
    public class StudentService : IStudentService
    {
        private readonly IStudentRepository _studentRepository;

        public StudentService(IStudentRepository studentRepository)
        {
            _studentRepository = studentRepository;
        }

        private static StudentViewModel MapToViewModel(Student s) => new StudentViewModel
        {
            StudentId        = s.StudentId,
            UserId           = s.UserId,
            AdmissionNo      = s.AdmissionNo,
            FirstName        = s.FirstName,
            LastName         = s.LastName,
            FullName         = s.FullName,
            Gender           = s.Gender,
            DateOfBirth      = s.DateOfBirth,
            Mobile           = s.Mobile,
            Email            = s.Email,
            Address          = s.Address,
            ParentName       = s.ParentName,
            ParentMobile     = s.ParentMobile,
            AdmissionDate    = s.AdmissionDate,
            ProfileImage     = s.ProfileImage,
            IsActive         = s.IsActive,
            CreatedAt        = s.CreatedAt,
            EnrollmentId     = s.EnrollmentId,
            BatchId          = s.BatchId,
            BatchName        = s.BatchName,
            CourseId         = s.CourseId,
            CourseName       = s.CourseName,
            EnrollmentStatus = s.EnrollmentStatus
        };

        private static BatchViewModel MapBatch(Batch b) => new BatchViewModel
        {
            BatchId   = b.BatchId,
            BatchName = b.BatchName,
            Capacity  = b.Capacity,
            Status    = b.Status,
            StartTime = b.StartTime.HasValue ? b.StartTime.Value.ToString(@"hh\:mm") : null,
            EndTime   = b.EndTime.HasValue ? b.EndTime.Value.ToString(@"hh\:mm") : null,
            RoomNo    = b.RoomNo,
            EnrolledCount = b.EnrolledCount
        };

        public async Task<PagedResult<StudentViewModel>> GetStudentsAsync(
            string? search = null,
            int page = 1,
            int pageSize = 6,
            string sortBy = "StudentId",
            string sortOrder = "DESC",
            int? courseId = null,
            int? batchId = null,
            string? statusFilter = null)
        {
            page = page < 1 ? 1 : page;
            pageSize = pageSize < 1 ? 6 : pageSize;

            var (students, totalCount) = await _studentRepository.GetPagedStudentsAsync(
                search, page, pageSize, sortBy, sortOrder, courseId, batchId, statusFilter);

            return new PagedResult<StudentViewModel>
            {
                Data          = students.Select(MapToViewModel).ToList(),
                TotalCount    = totalCount,
                PageNumber    = page,
                PageSize      = pageSize,
                SearchTerm    = search,
                SortColumn    = sortBy,
                SortDirection = sortOrder
            };
        }

        public async Task<StudentViewModel?> GetStudentByIdAsync(int studentId)
        {
            var student = await _studentRepository.GetStudentByIdAsync(studentId);
            return student == null ? null : MapToViewModel(student);
        }

        public async Task<StudentViewModel?> GetStudentByUserIdAsync(int userId)
        {
            var student = await _studentRepository.GetStudentByUserIdAsync(userId);
            return student == null ? null : MapToViewModel(student);
        }

        public async Task<(bool Success, string Message)> UpdateStudentProfileAsync(int studentId, string? gender, DateTime? dateOfBirth, string? address, string? profileImage)
        {
            if (studentId <= 0) return (false, "Invalid Student ID.");

            int result = await _studentRepository.UpdateStudentProfileAsync(studentId, gender, dateOfBirth, address, profileImage);
            if (result <= 0) return (false, "Failed to update profile.");

            return (true, "Profile updated successfully!");
        }

        public async Task<StudentAdmissionViewModel?> GetStudentForEditAsync(int studentId)
        {
            var student = await _studentRepository.GetStudentByIdAsync(studentId);
            if (student == null) return null;

            return new StudentAdmissionViewModel
            {
                StudentId     = student.StudentId,
                AdmissionNo   = student.AdmissionNo,
                FirstName     = student.FirstName,
                LastName      = student.LastName,
                Gender        = student.Gender,
                DateOfBirth   = student.DateOfBirth,
                Mobile        = student.Mobile ?? string.Empty,
                Email         = student.Email,
                Address       = student.Address,
                ParentName    = student.ParentName ?? string.Empty,
                ParentMobile  = student.ParentMobile ?? string.Empty,
                AdmissionDate = student.AdmissionDate,
                ProfileImage  = student.ProfileImage,
                IsActive      = student.IsActive,
                CourseId      = student.CourseId,
                BatchId       = student.BatchId
            };
        }

        public async Task<(bool Success, string Message, int StudentId)> CreateStudentAdmissionAsync(StudentAdmissionViewModel model)
        {
            if (string.IsNullOrWhiteSpace(model.FirstName))
                return (false, "First Name is required.", 0);
            if (string.IsNullOrWhiteSpace(model.LastName))
                return (false, "Last Name is required.", 0);
            if (string.IsNullOrWhiteSpace(model.Mobile))
                return (false, "Mobile Number is required.", 0);
            if (string.IsNullOrWhiteSpace(model.ParentName))
                return (false, "Parent / Guardian Name is required.", 0);
            if (string.IsNullOrWhiteSpace(model.ParentMobile))
                return (false, "Parent Contact Number is required.", 0);

            var student = new Student
            {
                AdmissionNo   = model.AdmissionNo?.Trim() ?? string.Empty,
                FirstName     = model.FirstName.Trim(),
                LastName      = model.LastName.Trim(),
                Gender        = model.Gender,
                DateOfBirth   = model.DateOfBirth,
                Mobile        = model.Mobile.Trim(),
                Email         = model.Email?.Trim(),
                Address       = model.Address?.Trim(),
                ParentName    = model.ParentName.Trim(),
                ParentMobile  = model.ParentMobile.Trim(),
                AdmissionDate = model.AdmissionDate == default ? DateTime.Today : model.AdmissionDate,
                ProfileImage  = model.ProfileImage,
                IsActive      = true
            };

            int studentId = await _studentRepository.CreateStudentAdmissionAsync(
                student, model.BatchId, student.AdmissionDate);

            if (studentId == -1)
                return (false, "A student with this Admission Number already exists.", 0);
            if (studentId <= 0)
                return (false, "Failed to register student. Please verify all fields.", 0);

            return (true, "Student admission successfully completed!", studentId);
        }

        public async Task<(bool Success, string Message)> UpdateStudentAsync(StudentAdmissionViewModel model)
        {
            if (model.StudentId <= 0)
                return (false, "Invalid Student ID.");
            if (string.IsNullOrWhiteSpace(model.FirstName))
                return (false, "First Name is required.");
            if (string.IsNullOrWhiteSpace(model.LastName))
                return (false, "Last Name is required.");
            if (string.IsNullOrWhiteSpace(model.Mobile))
                return (false, "Mobile Number is required.");
            if (string.IsNullOrWhiteSpace(model.ParentName))
                return (false, "Parent / Guardian Name is required.");
            if (string.IsNullOrWhiteSpace(model.ParentMobile))
                return (false, "Parent Contact Number is required.");

            var student = new Student
            {
                StudentId     = model.StudentId,
                AdmissionNo   = model.AdmissionNo?.Trim() ?? string.Empty,
                FirstName     = model.FirstName.Trim(),
                LastName      = model.LastName.Trim(),
                Gender        = model.Gender,
                DateOfBirth   = model.DateOfBirth,
                Mobile        = model.Mobile.Trim(),
                Email         = model.Email?.Trim(),
                Address       = model.Address?.Trim(),
                ParentName    = model.ParentName.Trim(),
                ParentMobile  = model.ParentMobile.Trim(),
                AdmissionDate = model.AdmissionDate,
                ProfileImage  = model.ProfileImage,
                IsActive      = model.IsActive
            };

            int result = await _studentRepository.UpdateStudentAsync(student, model.BatchId);

            if (result == -1)
                return (false, "Admission Number already in use by another student.");
            if (result <= 0)
                return (false, "Failed to update student details.");

            return (true, "Student details updated successfully!");
        }

        public async Task<(bool Success, string Message)> DeleteStudentAsync(int studentId)
        {
            if (studentId <= 0) return (false, "Invalid Student ID.");

            int result = await _studentRepository.DeleteOrDeactivateStudentAsync(studentId);

            if (result == 2)
                return (true, "Student has been deactivated because existing academic or financial records were found.");
            if (result == 1)
                return (true, "Student record deleted successfully.");

            return (false, "Failed to delete student.");
        }

        public async Task<StudentStatsViewModel> GetStudentStatsAsync()
        {
            var (total, active, inactive, enrolled, newThisMonth) = await _studentRepository.GetStudentStatsAsync();
            return new StudentStatsViewModel
            {
                TotalStudents          = total,
                ActiveStudents         = active,
                InactiveStudents       = inactive,
                EnrolledStudents       = enrolled,
                NewAdmissionsThisMonth = newThisMonth
            };
        }

        public async Task<string> GetNextAdmissionNumberAsync()
        {
            return await _studentRepository.GetNextAdmissionNumberAsync("ADM");
        }

        public async Task<IEnumerable<BatchViewModel>> GetBatchesByCourseAsync(int courseId)
        {
            if (courseId <= 0) return Enumerable.Empty<BatchViewModel>();
            var batches = await _studentRepository.GetBatchesByCourseAsync(courseId);
            return batches.Select(MapBatch).ToList();
        }
    }
}
