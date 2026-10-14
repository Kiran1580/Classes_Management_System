using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using CMS_BAL.Services.Interfaces;
using CMS_BAL.ViewModels;
using CMS_DAL.Models;
using CMS_DAL.Repositories.Interfaces;

namespace CMS_BAL.Services.Implementations
{
    public class TeacherService : ITeacherService
    {
        private readonly ITeacherRepository _teacherRepository;

        public TeacherService(ITeacherRepository teacherRepository)
        {
            _teacherRepository = teacherRepository;
        }

        public async Task<PagedResult<TeacherViewModel>> GetTeachersAsync(
            string? search,
            int page,
            int pageSize,
            string? sortBy,
            string? sortOrder,
            string? statusFilter)
        {
            page = page < 1 ? 1 : page;
            pageSize = pageSize < 1 ? 10 : pageSize;

            var (teachers, totalCount) = await _teacherRepository.GetPagedTeachersAsync(
                search, page, pageSize, sortBy, sortOrder, statusFilter);

            var list = teachers.Select(MapToViewModel).ToList();

            return new PagedResult<TeacherViewModel>
            {
                Data = list,
                TotalCount = totalCount,
                PageNumber = page,
                PageSize = pageSize,
                SearchTerm = search,
                SortColumn = sortBy,
                SortDirection = sortOrder
            };
        }

        public async Task<TeacherViewModel?> GetTeacherByIdAsync(int teacherId)
        {
            var teacher = await _teacherRepository.GetTeacherByIdAsync(teacherId);
            return teacher == null ? null : MapToViewModel(teacher);
        }

        public async Task<TeacherViewModel?> GetTeacherByUserIdAsync(int userId)
        {
            var teacher = await _teacherRepository.GetTeacherByUserIdAsync(userId);
            return teacher == null ? null : MapToViewModel(teacher);
        }

        public async Task<TeacherDetailsViewModel?> GetTeacherDetailsAsync(int teacherId)
        {
            var teacher = await _teacherRepository.GetTeacherByIdAsync(teacherId);
            if (teacher == null) return null;

            var batches = await _teacherRepository.GetTeacherBatchesAsync(teacherId);

            return new TeacherDetailsViewModel
            {
                Teacher = MapToViewModel(teacher),
                AssignedBatches = batches.Select(MapToBatchViewModel).ToList()
            };
        }

        public async Task<IEnumerable<TeacherBatchViewModel>> GetTeacherBatchesAsync(int teacherId)
        {
            var batches = await _teacherRepository.GetTeacherBatchesAsync(teacherId);
            return batches.Select(MapToBatchViewModel).ToList();
        }

        public async Task<TeacherStatsViewModel> GetTeacherStatsAsync()
        {
            var (total, active, inactive, assignedBatches) = await _teacherRepository.GetTeacherStatsAsync();
            return new TeacherStatsViewModel
            {
                TotalTeachers = total,
                ActiveTeachers = active,
                InactiveTeachers = inactive,
                AssignedBatches = assignedBatches
            };
        }

        public async Task<string> GetNextEmployeeCodeAsync()
        {
            return await _teacherRepository.GetNextEmployeeCodeAsync("TCH");
        }

        public async Task<(bool Success, string Message, int TeacherId)> CreateTeacherAsync(TeacherCreateViewModel model)
        {
            // Validations
            if (string.IsNullOrWhiteSpace(model.FirstName))
                return (false, "First Name is required.", 0);
            if (string.IsNullOrWhiteSpace(model.LastName))
                return (false, "Last Name is required.", 0);
            if (string.IsNullOrWhiteSpace(model.Email))
                return (false, "Email is required.", 0);
            if (string.IsNullOrWhiteSpace(model.Mobile) || !Regex.IsMatch(model.Mobile.Trim(), @"^[0-9]{10}$"))
                return (false, "A valid 10-digit Mobile number is required.", 0);
            if (string.IsNullOrWhiteSpace(model.Qualification))
                return (false, "Qualification is required.", 0);
            if (string.IsNullOrWhiteSpace(model.Password) || model.Password.Length < 6)
                return (false, "Password must be at least 6 characters long.", 0);

            // Auto-generate employee code if missing
            if (string.IsNullOrWhiteSpace(model.EmployeeCode))
            {
                model.EmployeeCode = await GetNextEmployeeCodeAsync();
            }

            string passwordHash = BCrypt.Net.BCrypt.HashPassword(model.Password.Trim());

            var teacher = new Teacher
            {
                EmployeeCode = model.EmployeeCode.Trim(),
                FirstName = model.FirstName.Trim(),
                LastName = model.LastName.Trim(),
                Mobile = model.Mobile.Trim(),
                Email = model.Email.Trim().ToLower(),
                Qualification = model.Qualification.Trim(),
                JoiningDate = model.JoiningDate,
                ProfileImage = model.ProfileImage,
                IsActive = model.IsActive
            };

            int teacherId = await _teacherRepository.CreateTeacherAsync(teacher, passwordHash);

            if (teacherId == -1)
                return (false, "An account with this email address already exists.", 0);
            if (teacherId == -2)
                return (false, "A teacher with this Employee Code already exists.", 0);
            if (teacherId <= 0)
                return (false, "Failed to create teacher account. Please try again.", 0);

            return (true, "Teacher created successfully!", teacherId);
        }

        public async Task<(bool Success, string Message)> UpdateTeacherAsync(TeacherEditViewModel model)
        {
            if (string.IsNullOrWhiteSpace(model.FirstName))
                return (false, "First Name is required.");
            if (string.IsNullOrWhiteSpace(model.LastName))
                return (false, "Last Name is required.");
            if (string.IsNullOrWhiteSpace(model.Email))
                return (false, "Email is required.");
            if (string.IsNullOrWhiteSpace(model.Mobile) || !Regex.IsMatch(model.Mobile.Trim(), @"^[0-9]{10}$"))
                return (false, "A valid 10-digit Mobile number is required.");
            if (string.IsNullOrWhiteSpace(model.Qualification))
                return (false, "Qualification is required.");

            var teacher = new Teacher
            {
                TeacherId = model.TeacherId,
                FirstName = model.FirstName.Trim(),
                LastName = model.LastName.Trim(),
                Mobile = model.Mobile.Trim(),
                Email = model.Email.Trim().ToLower(),
                Qualification = model.Qualification.Trim(),
                JoiningDate = model.JoiningDate,
                ProfileImage = model.ProfileImage,
                IsActive = model.IsActive
            };

            int result = await _teacherRepository.UpdateTeacherAsync(teacher);

            if (result == -1)
                return (false, "Another user is already registered with this email address.");
            if (result <= 0)
                return (false, "Teacher not found or update failed.");

            return (true, "Teacher updated successfully!");
        }

        public async Task<(bool Success, string Message)> DeleteTeacherAsync(int teacherId)
        {
            int result = await _teacherRepository.DeleteTeacherAsync(teacherId);

            if (result == -2)
                return (false, "Cannot delete this teacher because they are currently assigned to active batches/subjects. Please reassign their batches first.");
            if (result == -3)
                return (false, "Cannot delete this teacher because academic class sessions or attendance records are linked to them.");
            if (result == -4)
                return (false, "Cannot delete this teacher because study materials have been uploaded by them.");
            if (result == 1)
                return (true, "Teacher deleted successfully.");

            return (false, "Teacher not found or could not be deleted.");
        }

        public async Task<IEnumerable<TeacherViewModel>> GetAllActiveTeachersAsync()
        {
            var teachers = await _teacherRepository.GetAllActiveTeachersAsync();
            return teachers.Select(MapToViewModel).ToList();
        }

        // ==========================================
        // Helper Mappings
        // ==========================================
        private static TeacherViewModel MapToViewModel(Teacher t)
        {
            return new TeacherViewModel
            {
                TeacherId = t.TeacherId,
                UserId = t.UserId,
                EmployeeCode = t.EmployeeCode,
                FirstName = t.FirstName,
                LastName = t.LastName,
                Mobile = t.Mobile,
                Email = t.Email,
                Qualification = t.Qualification,
                JoiningDate = t.JoiningDate,
                ProfileImage = t.ProfileImage,
                IsActive = t.IsActive,
                CreatedAt = t.CreatedAt,
                AssignedBatchesCount = t.AssignedBatchesCount
            };
        }

        private static TeacherBatchViewModel MapToBatchViewModel(TeacherBatch b)
        {
            return new TeacherBatchViewModel
            {
                BatchSubjectId = b.BatchSubjectId,
                BatchId = b.BatchId,
                BatchName = b.BatchName,
                CourseId = b.CourseId,
                CourseName = b.CourseName,
                SubjectId = b.SubjectId,
                SubjectName = b.SubjectName,
                RoomNo = b.RoomNo,
                StartTime = b.StartTime.HasValue ? DateTime.Today.Add(b.StartTime.Value).ToString("hh:mm tt") : null,
                EndTime = b.EndTime.HasValue ? DateTime.Today.Add(b.EndTime.Value).ToString("hh:mm tt") : null,
                EnrolledStudentsCount = b.EnrolledStudentsCount,
                BatchStatus = b.BatchStatus
            };
        }
    }
}
