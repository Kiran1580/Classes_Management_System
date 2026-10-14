using System;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using CMS_BAL.Services.Interfaces;
using CMS_BAL.ViewModels;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;

namespace Classes_Management_System.Controllers
{
    [Authorize(Policy = "RequireAdminRole")]
    public class StudentController : Controller
    {
        private readonly IStudentService _studentService;
        private readonly ICourseService _courseService;
        private readonly IBatchService _batchService;
        private readonly IWebHostEnvironment _env;

        public StudentController(
            IStudentService studentService,
            ICourseService courseService,
            IBatchService batchService,
            IWebHostEnvironment env)
        {
            _studentService = studentService;
            _courseService  = courseService;
            _batchService   = batchService;
            _env            = env;
        }

        // ==========================================
        // 1. GET: /Admin/Student/Index
        // ==========================================
        [HttpGet]
        public async Task<IActionResult> Index(
            string? search       = null,
            int     page         = 1,
            int     pageSize     = 6,
            string  sortBy       = "StudentId",
            string  sortOrder    = "DESC",
            int?    courseId     = null,
            int?    batchId      = null,
            string? statusFilter = null)
        {
            var pagedResult   = await _studentService.GetStudentsAsync(search, page, pageSize, sortBy, sortOrder, courseId, batchId, statusFilter);
            var stats         = await _studentService.GetStudentStatsAsync();
            var activeCourses = await _courseService.GetActiveCoursesAsync();

            // Batches for filter: if courseId is selected, show batches of that course, otherwise empty or all
            var filterBatches = courseId.HasValue && courseId.Value > 0
                ? await _studentService.GetBatchesByCourseAsync(courseId.Value)
                : Enumerable.Empty<BatchViewModel>();

            ViewBag.Stats         = stats;
            ViewBag.ActiveCourses = activeCourses;
            ViewBag.FilterBatches = filterBatches;
            ViewBag.CourseId      = courseId;
            ViewBag.BatchId       = batchId;
            ViewBag.StatusFilter  = statusFilter;

            return View(pagedResult);
        }

        // ==========================================
        // 2. GET: /Admin/Student/Admission
        // ==========================================
        [HttpGet]
        public async Task<IActionResult> Admission()
        {
            var nextAdmissionNo = await _studentService.GetNextAdmissionNumberAsync();
            var activeCourses   = await _courseService.GetActiveCoursesAsync();

            var model = new StudentAdmissionViewModel
            {
                AdmissionNo   = nextAdmissionNo,
                AdmissionDate = DateTime.Today,
                Gender        = "Male",
                IsActive      = true
            };

            ViewBag.ActiveCourses = activeCourses;
            return View(model);
        }

        // ==========================================
        // 3. POST: /Admin/Student/Admission
        // ==========================================
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Admission(StudentAdmissionViewModel model, IFormFile? profilePhoto)
        {
            // Handle Profile Image Upload
            if (profilePhoto != null && profilePhoto.Length > 0)
            {
                var (isValid, errorMsg, filePath) = await SaveProfilePhotoAsync(profilePhoto);
                if (!isValid)
                {
                    ModelState.AddModelError("ProfileImage", errorMsg);
                }
                else
                {
                    model.ProfileImage = filePath;
                }
            }

            if (!ModelState.IsValid)
            {
                ViewBag.ActiveCourses = await _courseService.GetActiveCoursesAsync();
                if (model.CourseId.HasValue && model.CourseId.Value > 0)
                {
                    ViewBag.CourseBatches = await _studentService.GetBatchesByCourseAsync(model.CourseId.Value);
                }
                TempData["ErrorMessage"] = "Please fill in all required fields correctly.";
                return View(model);
            }

            var (success, message, studentId) = await _studentService.CreateStudentAdmissionAsync(model);

            if (success)
            {
                TempData["SuccessMessage"] = message;
                return RedirectToAction(nameof(Details), new { id = studentId });
            }

            TempData["ErrorMessage"] = message;
            ViewBag.ActiveCourses = await _courseService.GetActiveCoursesAsync();
            if (model.CourseId.HasValue && model.CourseId.Value > 0)
            {
                ViewBag.CourseBatches = await _studentService.GetBatchesByCourseAsync(model.CourseId.Value);
            }
            return View(model);
        }

        // ==========================================
        // 4. GET: /Admin/Student/Edit/5
        // ==========================================
        [HttpGet]
        public async Task<IActionResult> Edit(int id)
        {
            var model = await _studentService.GetStudentForEditAsync(id);
            if (model == null)
            {
                TempData["ErrorMessage"] = "Student not found.";
                return RedirectToAction(nameof(Index));
            }

            ViewBag.ActiveCourses = await _courseService.GetActiveCoursesAsync();
            if (model.CourseId.HasValue && model.CourseId.Value > 0)
            {
                ViewBag.CourseBatches = await _studentService.GetBatchesByCourseAsync(model.CourseId.Value);
            }

            return View(model);
        }

        // ==========================================
        // 5. POST: /Admin/Student/Edit
        // ==========================================
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Edit(StudentAdmissionViewModel model, IFormFile? profilePhoto)
        {
            if (profilePhoto != null && profilePhoto.Length > 0)
            {
                var (isValid, errorMsg, filePath) = await SaveProfilePhotoAsync(profilePhoto);
                if (!isValid)
                {
                    ModelState.AddModelError("ProfileImage", errorMsg);
                }
                else
                {
                    model.ProfileImage = filePath;
                }
            }

            if (!ModelState.IsValid)
            {
                ViewBag.ActiveCourses = await _courseService.GetActiveCoursesAsync();
                if (model.CourseId.HasValue && model.CourseId.Value > 0)
                {
                    ViewBag.CourseBatches = await _studentService.GetBatchesByCourseAsync(model.CourseId.Value);
                }
                TempData["ErrorMessage"] = "Please check validation errors.";
                return View(model);
            }

            var (success, message) = await _studentService.UpdateStudentAsync(model);

            if (success)
            {
                TempData["SuccessMessage"] = message;
                return RedirectToAction(nameof(Details), new { id = model.StudentId });
            }

            TempData["ErrorMessage"] = message;
            ViewBag.ActiveCourses = await _courseService.GetActiveCoursesAsync();
            if (model.CourseId.HasValue && model.CourseId.Value > 0)
            {
                ViewBag.CourseBatches = await _studentService.GetBatchesByCourseAsync(model.CourseId.Value);
            }
            return View(model);
        }

        // ==========================================
        // 6. GET: /Admin/Student/Details/5
        // ==========================================
        [HttpGet]
        public async Task<IActionResult> Details(int id)
        {
            var student = await _studentService.GetStudentByIdAsync(id);
            if (student == null)
            {
                TempData["ErrorMessage"] = "Student not found.";
                return RedirectToAction(nameof(Index));
            }

            return View(student);
        }

        // ==========================================
        // 7. POST: /Admin/Student/Delete/5
        // ==========================================
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Delete(int id)
        {
            var (success, message) = await _studentService.DeleteStudentAsync(id);

            if (success)
                TempData["SuccessMessage"] = message;
            else
                TempData["ErrorMessage"] = message;

            return RedirectToAction(nameof(Index));
        }

        // ==========================================
        // 8. GET: /Admin/Student/GetBatchesByCourse (AJAX)
        // ==========================================
        [HttpGet]
        public async Task<IActionResult> GetBatchesByCourse(int courseId)
        {
            var batches = await _studentService.GetBatchesByCourseAsync(courseId);
            return Json(batches);
        }

        // ==========================================
        // 9. GET: /Admin/Student/GetNextAdmissionNo (AJAX)
        // ==========================================
        [HttpGet]
        public async Task<IActionResult> GetNextAdmissionNo()
        {
            var nextNo = await _studentService.GetNextAdmissionNumberAsync();
            return Json(new { admissionNo = nextNo });
        }

        // ==========================================
        // Helper: Secure Photo Upload
        // ==========================================
        private async Task<(bool IsValid, string ErrorMessage, string? FilePath)> SaveProfilePhotoAsync(IFormFile file)
        {
            // Max size 3 MB
            if (file.Length > 3 * 1024 * 1024)
                return (false, "Photo size cannot exceed 3 MB.", null);

            var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
            var allowedExts = new[] { ".jpg", ".jpeg", ".png", ".webp" };
            if (!allowedExts.Contains(ext))
                return (false, "Only JPG, PNG or WEBP images are allowed.", null);

            string uploadsFolder = Path.Combine(_env.WebRootPath, "uploads", "students");
            if (!Directory.Exists(uploadsFolder))
                Directory.CreateDirectory(uploadsFolder);

            string uniqueFileName = $"stu_{Guid.NewGuid():N}{ext}";
            string fullPath = Path.Combine(uploadsFolder, uniqueFileName);

            using (var stream = new FileStream(fullPath, FileMode.Create))
            {
                await file.CopyToAsync(stream);
            }

            return (true, string.Empty, $"/uploads/students/{uniqueFileName}");
        }
    }
}
