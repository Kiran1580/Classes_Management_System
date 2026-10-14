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
    public class ProfileController : Controller
    {
        private readonly IStudentService _studentService;
        private readonly IAuthService _authService;
        private readonly IWebHostEnvironment _env;

        public ProfileController(
            IStudentService studentService,
            IAuthService authService,
            IWebHostEnvironment env)
        {
            _studentService = studentService;
            _authService = authService;
            _env = env;
        }

        [HttpGet]
        public async Task<IActionResult> Index()
        {
            var userIdClaim = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (!int.TryParse(userIdClaim, out int userId) || userId <= 0)
            {
                return RedirectToAction("Login", "Account");
            }

            if (User.IsInRole("Student"))
            {
                var student = await _studentService.GetStudentByUserIdAsync(userId);
                if (student == null)
                {
                    TempData["ErrorMessage"] = "Student profile not found. Please contact administration.";
                    return RedirectToAction("Index", "Dashboard", new { area = "Student" });
                }

                var model = new StudentProfileViewModel
                {
                    StudentId     = student.StudentId,
                    UserId        = student.UserId,
                    AdmissionNo   = student.AdmissionNo,
                    FirstName     = student.FirstName,
                    LastName      = student.LastName,
                    Email         = student.Email,
                    Mobile        = student.Mobile,
                    ParentName    = student.ParentName,
                    ParentMobile  = student.ParentMobile,
                    CourseName    = student.CourseName,
                    BatchName     = student.BatchName,
                    AdmissionDate = student.AdmissionDate,
                    Gender        = student.Gender,
                    DateOfBirth   = student.DateOfBirth,
                    Address       = student.Address,
                    ProfileImage  = student.ProfileImage
                };

                return View(model);
            }

            // For Admin or Teacher roles
            var user = await _authService.GetUserByIdAsync(userId);
            var generalModel = new StudentProfileViewModel
            {
                UserId       = userId,
                FirstName    = user?.FullName ?? User.Identity?.Name ?? "User",
                LastName     = "",
                Email        = user?.Email ?? "",
                Mobile       = user?.Mobile ?? "",
                AdmissionNo  = user?.RoleName ?? "Member"
            };

            return View(generalModel);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Update(StudentProfileViewModel model, IFormFile? photoFile)
        {
            if (!User.IsInRole("Student"))
            {
                TempData["ErrorMessage"] = "Only students can update profile information at this time.";
                return RedirectToAction(nameof(Index));
            }

            // Photo upload handling
            if (photoFile != null && photoFile.Length > 0)
            {
                var (isValid, errorMsg, filePath) = await SaveProfilePhotoAsync(photoFile);
                if (!isValid)
                {
                    ModelState.AddModelError("PhotoFile", errorMsg);
                }
                else
                {
                    model.ProfileImage = filePath;
                }
            }

            if (!ModelState.IsValid)
            {
                TempData["ErrorMessage"] = "Please fill in all required fields accurately.";
                return View(nameof(Index), model);
            }

            var (success, message) = await _studentService.UpdateStudentProfileAsync(
                model.StudentId,
                model.Gender,
                model.DateOfBirth,
                model.Address,
                model.ProfileImage);

            if (success)
            {
                TempData["SuccessMessage"] = "Your profile has been successfully updated!";
                return RedirectToAction(nameof(Index));
            }

            TempData["ErrorMessage"] = message;
            return View(nameof(Index), model);
        }

        private async Task<(bool IsValid, string ErrorMessage, string? FilePath)> SaveProfilePhotoAsync(IFormFile file)
        {
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
