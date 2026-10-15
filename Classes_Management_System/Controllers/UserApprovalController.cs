using System.Threading.Tasks;
using CMS_BAL.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Classes_Management_System.Controllers
{
    [Authorize(Roles = "Admin")]
    public class UserApprovalController : Controller
    {
        private readonly IAuthService _authService;

        public UserApprovalController(IAuthService authService)
        {
            _authService = authService;
        }

        [HttpGet]
        public async Task<IActionResult> Index(
            string? search = null,
            string? role = null,
            string? sortBy = "AppliedDate",
            string? sortOrder = "DESC",
            int page = 1,
            int pageSize = 10)
        {
            var (pagedResult, totalPending, studentPending, teacherPending) =
                await _authService.GetPagedPendingRegistrationsAsync(search, role, page, pageSize, sortBy, sortOrder);

            ViewBag.TotalPending = totalPending;
            ViewBag.StudentPending = studentPending;
            ViewBag.TeacherPending = teacherPending;
            ViewBag.CurrentRole = string.IsNullOrWhiteSpace(role) ? "All" : role;

            return View(pagedResult);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Approve(int id, string? returnRole = null)
        {
            var (success, message) = await _authService.ApproveUserAsync(id);
            if (success)
            {
                TempData["SuccessMessage"] = message;
            }
            else
            {
                TempData["ErrorMessage"] = message;
            }

            if (!string.IsNullOrWhiteSpace(returnRole) && !string.Equals(returnRole, "All", System.StringComparison.OrdinalIgnoreCase))
            {
                return RedirectToAction(nameof(Index), new { role = returnRole });
            }

            return RedirectToAction(nameof(Index));
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Reject(int id, string? returnRole = null)
        {
            var (success, message) = await _authService.RejectUserAsync(id);
            if (success)
            {
                TempData["SuccessMessage"] = message;
            }
            else
            {
                TempData["ErrorMessage"] = message;
            }

            if (!string.IsNullOrWhiteSpace(returnRole) && !string.Equals(returnRole, "All", System.StringComparison.OrdinalIgnoreCase))
            {
                return RedirectToAction(nameof(Index), new { role = returnRole });
            }

            return RedirectToAction(nameof(Index));
        }
    }
}
