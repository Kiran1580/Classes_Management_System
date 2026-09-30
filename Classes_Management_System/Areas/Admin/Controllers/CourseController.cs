using System.Linq;
using System.Threading.Tasks;
using CMS_BAL.Services.Interfaces;
using CMS_BAL.ViewModels;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Classes_Management_System.Areas.Admin.Controllers
{
    [Area("Admin")]
    [Authorize(Roles = "Admin")]
    public class CourseController : Controller
    {
        private readonly ICourseService _courseService;

        public CourseController(ICourseService courseService)
        {
            _courseService = courseService;
        }

        // ==========================================
        // 1. COURSES PAGE (Index Action)
        // ==========================================
        [HttpGet]
        public async Task<IActionResult> Index(
            string? search = null, 
            int page = 1, 
            int pageSize = 6, 
            string sortBy = "Id", 
            string sortOrder = "DESC")
        {
            var model = await _courseService.GetCoursesAsync(search, page, pageSize, sortBy, sortOrder);
            var allCourses = (await _courseService.GetAllCoursesAsync()).ToList();
            var allSubjects = (await _courseService.GetAllSubjectsAsync()).ToList();

            ViewBag.Search = search;
            ViewBag.SortBy = sortBy;
            ViewBag.SortOrder = sortOrder;
            ViewBag.TotalCourses = allCourses.Count;
            ViewBag.ActiveCourses = allCourses.Count(c => c.IsActive);
            ViewBag.TotalSubjects = allSubjects.Count;
            ViewBag.AvailableSubjects = allSubjects.Where(s => s.IsActive).ToList();
            ViewBag.AllAvailableSubjects = ViewBag.AvailableSubjects;

            return View(model);
        }

        // ==========================================
        // 2. SUBJECTS PAGE (Subjects Action)
        // ==========================================
        [HttpGet]
        public async Task<IActionResult> Subjects(
            string? search = null, 
            int page = 1, 
            int pageSize = 6, 
            string sortBy = "Name", 
            string sortOrder = "ASC")
        {
            var model = await _courseService.GetSubjectsAsync(search, page, pageSize, sortBy, sortOrder);
            var allCourses = (await _courseService.GetAllCoursesAsync()).ToList();
            var allSubjects = (await _courseService.GetAllSubjectsAsync()).ToList();

            ViewBag.Search = search;
            ViewBag.SortBy = sortBy;
            ViewBag.SortOrder = sortOrder;
            ViewBag.TotalCourses = allCourses.Count;
            ViewBag.ActiveCourses = allCourses.Count(c => c.IsActive);
            ViewBag.TotalSubjects = allSubjects.Count;
            ViewBag.AvailableSubjects = allSubjects.Where(s => s.IsActive).ToList();
            ViewBag.AllAvailableSubjects = ViewBag.AvailableSubjects;

            return View(model);
        }

        // ==========================================
        // Course CRUD
        // ==========================================
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Create(CourseViewModel model)
        {
            if (!ModelState.IsValid)
            {
                TempData["ErrorMessage"] = "Please fill all required fields.";
                return RedirectToAction(nameof(Index));
            }

            model.IsActive = Request.Form["IsActive"].Any(v => v != null && v.Equals("true", System.StringComparison.OrdinalIgnoreCase));
            var (success, message, _) = await _courseService.CreateCourseAsync(model);
            TempData[success ? "SuccessMessage" : "ErrorMessage"] = message;
            return RedirectToAction(nameof(Index));
        }

        [HttpGet]
        public async Task<IActionResult> GetCourse(int id)
        {
            var course = await _courseService.GetCourseByIdAsync(id);
            if (course == null) return NotFound();

            return Json(new
            {
                course.CourseId,
                course.CourseName,
                course.Duration,
                course.Description,
                course.IsActive,
                selectedSubjectIds = course.AssignedSubjects.Select(s => s.SubjectId).ToList()
            });
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Edit(CourseViewModel model)
        {
            if (!ModelState.IsValid)
            {
                TempData["ErrorMessage"] = "Please fill all required fields.";
                return RedirectToAction(nameof(Index));
            }

            model.IsActive = Request.Form["IsActive"].Any(v => v != null && v.Equals("true", System.StringComparison.OrdinalIgnoreCase));
            var (success, message) = await _courseService.UpdateCourseAsync(model);
            TempData[success ? "SuccessMessage" : "ErrorMessage"] = message;
            return RedirectToAction(nameof(Index));
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Delete(int id)
        {
            var (success, message) = await _courseService.DeleteCourseAsync(id);
            TempData[success ? "SuccessMessage" : "ErrorMessage"] = message;
            return RedirectToAction(nameof(Index));
        }

        // ==========================================
        // Subject CRUD
        // ==========================================
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> CreateSubject(SubjectViewModel model, string? returnAction = null)
        {
            if (!ModelState.IsValid)
            {
                TempData["ErrorMessage"] = "Subject Name is required.";
                return RedirectToAction(returnAction == "Subjects" ? nameof(Subjects) : nameof(Index));
            }

            model.IsActive = Request.Form["IsActive"].Any(v => v != null && v.Equals("true", System.StringComparison.OrdinalIgnoreCase));
            var (success, message, _) = await _courseService.CreateSubjectAsync(model);
            TempData[success ? "SuccessMessage" : "ErrorMessage"] = message;
            return RedirectToAction(returnAction == "Subjects" ? nameof(Subjects) : nameof(Index));
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> EditSubject(SubjectViewModel model, string? returnAction = null)
        {
            if (!ModelState.IsValid)
            {
                TempData["ErrorMessage"] = "Subject Name is required.";
                return RedirectToAction(returnAction == "Subjects" ? nameof(Subjects) : nameof(Index));
            }

            model.IsActive = Request.Form["IsActive"].Any(v => v != null && v.Equals("true", System.StringComparison.OrdinalIgnoreCase));
            var (success, message) = await _courseService.UpdateSubjectAsync(model);
            TempData[success ? "SuccessMessage" : "ErrorMessage"] = message;
            return RedirectToAction(returnAction == "Subjects" ? nameof(Subjects) : nameof(Index));
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> DeleteSubject(int id, string? returnAction = null)
        {
            var (success, message) = await _courseService.DeleteSubjectAsync(id);
            TempData[success ? "SuccessMessage" : "ErrorMessage"] = message;
            return RedirectToAction(returnAction == "Subjects" ? nameof(Subjects) : nameof(Index));
        }
    }
}
