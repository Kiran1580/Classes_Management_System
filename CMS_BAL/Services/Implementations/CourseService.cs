using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using CMS_BAL.Services.Interfaces;
using CMS_BAL.ViewModels;
using CMS_DAL.Models;
using CMS_DAL.Repositories.Interfaces;

namespace CMS_BAL.Services.Implementations
{
    public class CourseService : ICourseService
    {
        private readonly ICourseRepository _courseRepository;

        public CourseService(ICourseRepository courseRepository)
        {
            _courseRepository = courseRepository;
        }

        // ==========================================
        // 1. Paged Courses: returns { Data, TotalCount }
        // ==========================================
        public async Task<PagedResult<CourseViewModel>> GetCoursesAsync(string? search = null, int page = 1, int pageSize = 6, string sortBy = "Id", string sortOrder = "DESC")
        {
            page = page < 1 ? 1 : page;
            pageSize = pageSize < 1 ? 6 : pageSize;

            var (courses, totalCount) = await _courseRepository.GetPagedCoursesAsync(search, page, pageSize, sortBy, sortOrder);

            var list = new List<CourseViewModel>();
            foreach (var c in courses)
            {
                var assigned = await _courseRepository.GetSubjectsByCourseIdAsync(c.CourseId);
                list.Add(new CourseViewModel
                {
                    CourseId = c.CourseId,
                    CourseName = c.CourseName,
                    Description = c.Description,
                    Duration = c.Duration,
                    IsActive = c.IsActive,
                    CreatedAt = c.CreatedAt,
                    SubjectsCount = c.SubjectsCount,
                    BatchesCount = c.BatchesCount,
                    AssignedSubjects = assigned.Select(s => new SubjectViewModel
                    {
                        SubjectId = s.SubjectId,
                        SubjectName = s.SubjectName
                    }).ToList()
                });
            }

            return new PagedResult<CourseViewModel>
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

        // ==========================================
        // 2. Paged Subjects: returns { Data, TotalCount }
        // ==========================================
        public async Task<PagedResult<SubjectViewModel>> GetSubjectsAsync(string? search = null, int page = 1, int pageSize = 6, string sortBy = "Name", string sortOrder = "ASC")
        {
            page = page < 1 ? 1 : page;
            pageSize = pageSize < 1 ? 6 : pageSize;

            var (subjects, totalCount) = await _courseRepository.GetPagedSubjectsAsync(search, page, pageSize, sortBy, sortOrder);

            var list = subjects.Select(s => new SubjectViewModel
            {
                SubjectId = s.SubjectId,
                SubjectName = s.SubjectName,
                Description = s.Description,
                IsActive = s.IsActive,
                CreatedAt = s.CreatedAt,
                CoursesCount = s.CoursesCount
            }).ToList();

            return new PagedResult<SubjectViewModel>
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

        // ==========================================
        // 3. Courses CRUD
        // ==========================================
        public async Task<IEnumerable<CourseViewModel>> GetAllCoursesAsync()
        {
            var courses = await _courseRepository.GetAllCoursesAsync();
            return courses.Select(c => new CourseViewModel
            {
                CourseId = c.CourseId,
                CourseName = c.CourseName,
                Description = c.Description,
                Duration = c.Duration,
                IsActive = c.IsActive,
                CreatedAt = c.CreatedAt,
                SubjectsCount = c.SubjectsCount,
                BatchesCount = c.BatchesCount
            }).ToList();
        }

        public async Task<CourseViewModel?> GetCourseByIdAsync(int courseId)
        {
            var course = await _courseRepository.GetCourseByIdAsync(courseId);
            if (course == null) return null;

            var assigned = await _courseRepository.GetSubjectsByCourseIdAsync(courseId);
            var allSubjects = await _courseRepository.GetAllSubjectsAsync();

            return new CourseViewModel
            {
                CourseId = course.CourseId,
                CourseName = course.CourseName,
                Description = course.Description,
                Duration = course.Duration,
                IsActive = course.IsActive,
                CreatedAt = course.CreatedAt,
                SubjectsCount = course.SubjectsCount,
                BatchesCount = course.BatchesCount,
                SelectedSubjectIds = assigned.Select(s => s.SubjectId).ToList(),
                AssignedSubjects = assigned.Select(s => new SubjectViewModel { SubjectId = s.SubjectId, SubjectName = s.SubjectName }).ToList(),
                AvailableSubjects = allSubjects.Select(s => new SubjectViewModel { SubjectId = s.SubjectId, SubjectName = s.SubjectName }).ToList()
            };
        }

        public async Task<(bool Success, string Message, int CourseId)> CreateCourseAsync(CourseViewModel model)
        {
            if (string.IsNullOrWhiteSpace(model.CourseName))
                return (false, "Course Name is required.", 0);

            var course = new Course
            {
                CourseName = model.CourseName.Trim(),
                Description = model.Description?.Trim(),
                Duration = model.Duration?.Trim(),
                IsActive = model.IsActive
            };

            int courseId = await _courseRepository.CreateCourseAsync(course);
            if (courseId == -1) return (false, "A course with this name already exists.", 0);
            if (courseId <= 0) return (false, "Failed to create course.", 0);

            if (model.SelectedSubjectIds != null && model.SelectedSubjectIds.Any())
                await _courseRepository.AssignSubjectsToCourseAsync(courseId, model.SelectedSubjectIds);

            return (true, "Course created successfully!", courseId);
        }

        public async Task<(bool Success, string Message)> UpdateCourseAsync(CourseViewModel model)
        {
            if (string.IsNullOrWhiteSpace(model.CourseName))
                return (false, "Course Name is required.");

            var course = new Course
            {
                CourseId = model.CourseId,
                CourseName = model.CourseName.Trim(),
                Description = model.Description?.Trim(),
                Duration = model.Duration?.Trim(),
                IsActive = model.IsActive
            };

            int result = await _courseRepository.UpdateCourseAsync(course);
            if (result == -1) return (false, "Another course with this name already exists.");
            if (result <= 0) return (false, "Failed to update course.");

            await _courseRepository.AssignSubjectsToCourseAsync(model.CourseId, model.SelectedSubjectIds ?? new List<int>());
            return (true, "Course updated successfully!");
        }

        public async Task<(bool Success, string Message)> DeleteCourseAsync(int courseId)
        {
            int result = await _courseRepository.DeleteCourseAsync(courseId);
            if (result == 2) return (true, "Course deactivated because it is linked to existing batches.");
            if (result == 1) return (true, "Course deleted successfully.");
            return (false, "Failed to delete course.");
        }

        // ==========================================
        // 4. Subjects CRUD
        // ==========================================
        public async Task<IEnumerable<SubjectViewModel>> GetAllSubjectsAsync()
        {
            var subjects = await _courseRepository.GetAllSubjectsAsync();
            return subjects.Select(s => new SubjectViewModel
            {
                SubjectId = s.SubjectId,
                SubjectName = s.SubjectName,
                Description = s.Description,
                IsActive = s.IsActive,
                CreatedAt = s.CreatedAt,
                CoursesCount = s.CoursesCount
            }).ToList();
        }

        public async Task<SubjectViewModel?> GetSubjectByIdAsync(int subjectId)
        {
            var subject = await _courseRepository.GetSubjectByIdAsync(subjectId);
            if (subject == null) return null;

            return new SubjectViewModel
            {
                SubjectId = subject.SubjectId,
                SubjectName = subject.SubjectName,
                Description = subject.Description,
                IsActive = subject.IsActive,
                CreatedAt = subject.CreatedAt,
                CoursesCount = subject.CoursesCount
            };
        }

        public async Task<(bool Success, string Message, int SubjectId)> CreateSubjectAsync(SubjectViewModel model)
        {
            if (string.IsNullOrWhiteSpace(model.SubjectName))
                return (false, "Subject Name is required.", 0);

            var subject = new Subject
            {
                SubjectName = model.SubjectName.Trim(),
                Description = model.Description?.Trim(),
                IsActive = model.IsActive
            };

            int subjectId = await _courseRepository.CreateSubjectAsync(subject);
            if (subjectId == -1) return (false, "A subject with this name already exists.", 0);
            if (subjectId <= 0) return (false, "Failed to create subject.", 0);

            return (true, "Subject created successfully!", subjectId);
        }

        public async Task<(bool Success, string Message)> UpdateSubjectAsync(SubjectViewModel model)
        {
            if (string.IsNullOrWhiteSpace(model.SubjectName))
                return (false, "Subject Name is required.");

            var subject = new Subject
            {
                SubjectId = model.SubjectId,
                SubjectName = model.SubjectName.Trim(),
                Description = model.Description?.Trim(),
                IsActive = model.IsActive
            };

            int result = await _courseRepository.UpdateSubjectAsync(subject);
            if (result == -1) return (false, "Another subject with this name already exists.");
            if (result <= 0) return (false, "Failed to update subject.");

            return (true, "Subject updated successfully!");
        }

        public async Task<(bool Success, string Message)> DeleteSubjectAsync(int subjectId)
        {
            int result = await _courseRepository.DeleteSubjectAsync(subjectId);
            if (result == 2) return (true, "Subject deactivated because it is assigned to batches.");
            if (result == 1) return (true, "Subject deleted successfully.");
            return (false, "Failed to delete subject.");
        }

        // ==========================================
        // 5. Mappings
        // ==========================================
        public async Task<IEnumerable<SubjectViewModel>> GetSubjectsByCourseIdAsync(int courseId)
        {
            var subjects = await _courseRepository.GetSubjectsByCourseIdAsync(courseId);
            return subjects.Select(s => new SubjectViewModel
            {
                SubjectId = s.SubjectId,
                SubjectName = s.SubjectName,
                Description = s.Description,
                IsActive = s.IsActive,
                CreatedAt = s.CreatedAt
            }).ToList();
        }

        public async Task<bool> AssignSubjectsToCourseAsync(int courseId, IEnumerable<int> subjectIds)
        {
            return await _courseRepository.AssignSubjectsToCourseAsync(courseId, subjectIds);
        }
    }
}
