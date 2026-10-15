using System;
using System.IO;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;
using CMS_BAL.Services.Interfaces;
using CMS_BAL.ViewModels;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;

namespace Classes_Management_System.Controllers
{
    [Authorize]
    public class TeacherController : Controller
    {
        private readonly ITeacherService _teacherService;
        private readonly IWebHostEnvironment _env;

        public TeacherController(ITeacherService teacherService, IWebHostEnvironment env)
        {
            _teacherService = teacherService;
            _env = env;
        }

        // ==========================================
        // 1. GET: /Teacher/Index (Admin only)
        // ==========================================
        [Authorize(Roles = "Admin")]
        [HttpGet]
        public async Task<IActionResult> Index(
            string? search = null,
            int page = 1,
            int pageSize = 8,
            string sortBy = "TeacherId",
            string sortOrder = "DESC",
            string? statusFilter = null)
        {
            var pagedResult = await _teacherService.GetTeachersAsync(search, page, pageSize, sortBy, sortOrder, statusFilter);
            var stats = await _teacherService.GetTeacherStatsAsync();

            ViewBag.Stats = stats;
            ViewBag.CurrentSearch = search;
            ViewBag.CurrentSortBy = sortBy;
            ViewBag.CurrentSortOrder = sortOrder;
            ViewBag.StatusFilter = statusFilter;

            return View(pagedResult);
        }

        // ==========================================
        // 2. GET: /Teacher/Create (Admin only)
        // ==========================================
        [Authorize(Roles = "Admin")]
        [HttpGet]
        public async Task<IActionResult> Create()
        {
            var nextCode = await _teacherService.GetNextEmployeeCodeAsync();
            var model = new TeacherCreateViewModel
            {
                EmployeeCode = nextCode,
                JoiningDate = DateTime.Today,
                IsActive = true,
                Password = "Teacher@123",
                ConfirmPassword = "Teacher@123"
            };

            return View(model);
        }

        // ==========================================
        // 3. POST: /Teacher/Create (Admin only)
        // ==========================================
        [Authorize(Roles = "Admin")]
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Create(TeacherCreateViewModel model, IFormFile? profilePhoto)
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
                TempData["ErrorMessage"] = "Please fill in all required fields correctly.";
                return View(model);
            }

            var (success, message, teacherId) = await _teacherService.CreateTeacherAsync(model);

            if (success)
            {
                TempData["SuccessMessage"] = message;
                return RedirectToAction(nameof(Details), new { id = teacherId });
            }

            TempData["ErrorMessage"] = message;
            return View(model);
        }

        // ==========================================
        // 4. GET: /Teacher/Edit/{id} (Admin only)
        // ==========================================
        [Authorize(Roles = "Admin")]
        [HttpGet]
        public async Task<IActionResult> Edit(int id)
        {
            var teacher = await _teacherService.GetTeacherByIdAsync(id);
            if (teacher == null) return NotFound();

            var model = new TeacherEditViewModel
            {
                TeacherId = teacher.TeacherId,
                UserId = teacher.UserId,
                EmployeeCode = teacher.EmployeeCode,
                FirstName = teacher.FirstName,
                LastName = teacher.LastName,
                Mobile = teacher.Mobile ?? string.Empty,
                Email = teacher.Email ?? string.Empty,
                Qualification = teacher.Qualification ?? string.Empty,
                JoiningDate = teacher.JoiningDate ?? DateTime.Today,
                ProfileImage = teacher.ProfileImage,
                IsActive = teacher.IsActive
            };

            return View(model);
        }

        // ==========================================
        // 5. POST: /Teacher/Edit
        // ==========================================
        [Authorize(Roles = "Admin")]
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Edit(TeacherEditViewModel model, IFormFile? profilePhoto)
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
                TempData["ErrorMessage"] = "Please fix the validation errors before saving.";
                return View(model);
            }

            var (success, message) = await _teacherService.UpdateTeacherAsync(model);

            if (success)
            {
                TempData["SuccessMessage"] = message;
                return RedirectToAction(nameof(Details), new { id = model.TeacherId });
            }

            TempData["ErrorMessage"] = message;
            return View(model);
        }

        // ==========================================
        // 6. GET: /Teacher/Details/{id} (Admin or Own Profile)
        // ==========================================
        [HttpGet]
        public async Task<IActionResult> Details(int id)
        {
            var details = await _teacherService.GetTeacherDetailsAsync(id);
            if (details == null) return NotFound();

            // If non-admin teacher, check that they only view their own details
            if (!User.IsInRole("Admin"))
            {
                var currentUserIdStr = User.FindFirstValue(ClaimTypes.NameIdentifier);
                if (int.TryParse(currentUserIdStr, out int currentUserId))
                {
                    if (details.Teacher.UserId != currentUserId)
                    {
                        return Forbid();
                    }
                }
            }

            return View(details);
        }

        // ==========================================
        // 7. POST: /Teacher/Delete/{id} (Admin only)
        // ==========================================
        [Authorize(Roles = "Admin")]
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Delete(int id)
        {
            var (success, message) = await _teacherService.DeleteTeacherAsync(id);

            if (success)
                TempData["SuccessMessage"] = message;
            else
                TempData["ErrorMessage"] = message;

            return RedirectToAction(nameof(Index));
        }

        // ==========================================
        // 8. GET: /Teacher/MyBatches (Teacher Portal View)
        // ==========================================
        [Authorize(Roles = "Teacher")]
        [HttpGet]
        public async Task<IActionResult> MyBatches()
        {
            var currentUserIdStr = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (!int.TryParse(currentUserIdStr, out int currentUserId))
            {
                return Unauthorized();
            }

            var teacher = await _teacherService.GetTeacherByUserIdAsync(currentUserId);
            if (teacher == null)
            {
                ViewBag.Teacher = new TeacherViewModel { FirstName = User.Identity?.Name ?? "Teacher", LastName = "", EmployeeCode = "PENDING" };
                return View(new List<BatchViewModel>());
            }

            var batches = await _teacherService.GetTeacherBatchesAsync(teacher.TeacherId);

            ViewBag.Teacher = teacher;
            return View(batches);
        }

        // ==========================================
        // Helper: Secure Photo Upload
        // ==========================================
        private async Task<(bool IsValid, string ErrorMessage, string? FilePath)> SaveProfilePhotoAsync(IFormFile file)
        {
            if (file.Length > 3 * 1024 * 1024)
                return (false, "Photo size cannot exceed 3 MB.", null);

            var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
            var allowedExts = new[] { ".jpg", ".jpeg", ".png", ".webp" };
            if (!allowedExts.Contains(ext))
                return (false, "Only JPG, PNG or WEBP images are allowed.", null);

            string uploadsFolder = Path.Combine(_env.WebRootPath, "uploads", "teachers");
            if (!Directory.Exists(uploadsFolder))
                Directory.CreateDirectory(uploadsFolder);

            string uniqueFileName = $"tch_{Guid.NewGuid():N}{ext}";
            string fullPath = Path.Combine(uploadsFolder, uniqueFileName);

            using (var stream = new FileStream(fullPath, FileMode.Create))
            {
                await file.CopyToAsync(stream);
            }

            return (true, string.Empty, $"/uploads/teachers/{uniqueFileName}");
        }
    }
}
