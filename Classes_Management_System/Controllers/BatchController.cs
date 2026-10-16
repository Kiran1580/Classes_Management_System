using System;
using System.Linq;
using System.Threading.Tasks;
using CMS_BAL.Services.Interfaces;
using CMS_BAL.ViewModels;
using CMS_DAL.Repositories.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Classes_Management_System.Controllers
{
    [Authorize(Policy = "RequireAdminRole")]
    public class BatchController : Controller
    {
        private readonly IBatchService _batchService;
        private readonly ICourseService _courseService;
        private readonly IAcademicYearRepository _academicYearRepo;

        public BatchController(IBatchService batchService, ICourseService courseService, IAcademicYearRepository academicYearRepo)
        {
            _batchService     = batchService;
            _courseService    = courseService;
            _academicYearRepo = academicYearRepo;
        }

        // ==========================================
        // GET: /Admin/Batch/Index
        // ==========================================
        [HttpGet]
        public async Task<IActionResult> Index(
            string? search    = null,
            int     page      = 1,
            int     pageSize  = 6,
            string  sortBy    = "BatchId",
            string  sortOrder = "DESC",
            int?    courseFilter  = null,
            string? statusFilter  = null)
        {
            var pagedResult   = await _batchService.GetBatchesAsync(search, page, pageSize, sortBy, sortOrder, courseFilter, statusFilter);
            var stats         = await _batchService.GetBatchStatsAsync();
            var allCourses    = await _courseService.GetAllCoursesAsync();
            var activeCourses = await _courseService.GetActiveCoursesAsync();
            var currentYear   = await _academicYearRepo.GetCurrentAcademicYearAsync();

            ViewBag.TotalBatches       = stats.TotalBatches;
            ViewBag.ActiveBatches      = stats.ActiveBatches;
            ViewBag.InactiveBatches    = stats.InactiveBatches;
            ViewBag.TotalEnrolled      = stats.TotalEnrolled;
            ViewBag.CoursesWithBatches = stats.CoursesWithBatches;
            ViewBag.AllCourses         = allCourses;
            ViewBag.ActiveCourses      = activeCourses;
            ViewBag.CourseFilter       = courseFilter;
            ViewBag.StatusFilter       = statusFilter;
            ViewBag.CurrentAcademicYearId = currentYear?.AcademicYearId ?? 1;

            return View(pagedResult);
        }

        // ==========================================
        // POST: /Admin/Batch/Create
        // ==========================================
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Create(BatchViewModel model)
        {
            // Read Status from form (select dropdown)
            model.Status = Request.Form["Status"].FirstOrDefault() ?? "Active";

            if (!ModelState.IsValid)
            {
                TempData["ErrorMessage"] = "Please fill in all required fields correctly.";
                return RedirectToAction(nameof(Index));
            }

            var (success, message, _) = await _batchService.CreateBatchAsync(model);

            if (success)
                TempData["SuccessMessage"] = message;
            else
                TempData["ErrorMessage"] = message;

            return RedirectToAction(nameof(Index));
        }

        // ==========================================
        // POST: /Admin/Batch/Edit
        // ==========================================
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Edit(BatchViewModel model)
        {
            // Read Status from form (select dropdown)
            model.Status = Request.Form["Status"].FirstOrDefault() ?? "Active";

            if (!ModelState.IsValid)
            {
                TempData["ErrorMessage"] = "Please fill in all required fields correctly.";
                return RedirectToAction(nameof(Index));
            }

            var (success, message) = await _batchService.UpdateBatchAsync(model);

            if (success)
                TempData["SuccessMessage"] = message;
            else
                TempData["ErrorMessage"] = message;

            return RedirectToAction(nameof(Index));
        }

        // ==========================================
        // POST: /Admin/Batch/Delete
        // ==========================================
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Delete(int id)
        {
            var (success, message) = await _batchService.DeleteBatchAsync(id);

            if (success)
                TempData["SuccessMessage"] = message;
            else
                TempData["ErrorMessage"] = message;

            return RedirectToAction(nameof(Index));
        }

        // ==========================================
        // GET: /Admin/Batch/GetBatch?id=x  (AJAX)
        // ==========================================
        [HttpGet]
        public async Task<IActionResult> GetBatch(int id)
        {
            var batch = await _batchService.GetBatchByIdAsync(id);
            if (batch == null) return NotFound();
            return Json(batch);
        }

        // ==========================================
        // GET: /Admin/Batch/GetFacultyAssignments?batchId=x (AJAX)
        // ==========================================
        [HttpGet]
        public async Task<IActionResult> GetFacultyAssignments(int batchId)
        {
            var data = await _batchService.GetBatchFacultyDetailsAsync(batchId);
            if (data == null)
                return Json(new { success = false, message = "Batch not found." });

            return Json(new { success = true, data });
        }

        // ==========================================
        // POST: /Admin/Batch/SaveFacultyAssignments (AJAX JSON)
        // ==========================================
        [HttpPost]
        public async Task<IActionResult> SaveFacultyAssignments([FromBody] SaveBatchFacultyRequest request)
        {
            if (request == null || request.BatchId <= 0)
                return Json(new { success = false, message = "Invalid request payload." });

            var (success, message) = await _batchService.SaveBatchFacultyAssignmentsAsync(request);
            return Json(new { success, message });
        }
    }
}
