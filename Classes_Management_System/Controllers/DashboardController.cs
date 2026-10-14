using System;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;
using CMS_BAL.Services.Interfaces;
using CMS_BAL.ViewModels;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Classes_Management_System.Controllers
{
    [Authorize]
    public class DashboardController : Controller
    {
        private readonly IDashboardService _dashboardService;
        private readonly IStudentService _studentService;
        private readonly IAuthService _authService;

        public DashboardController(
            IDashboardService dashboardService,
            IStudentService studentService,
            IAuthService authService)
        {
            _dashboardService = dashboardService;
            _studentService = studentService;
            _authService = authService;
        }

        public async Task<IActionResult> Index()
        {
            var roleName = User.FindFirstValue(ClaimTypes.Role) ?? "Student";
            var userIdClaim = User.FindFirstValue(ClaimTypes.NameIdentifier);
            int.TryParse(userIdClaim, out int userId);
            var userName = User.Identity?.Name ?? "User";

            var model = new UnifiedDashboardViewModel
            {
                RoleName = roleName,
                UserFullName = userName,
                UserId = userId
            };

            if (model.IsAdmin)
            {
                model.AdminStats = await _dashboardService.GetAdminDashboardStatsAsync();
                var pending = await _authService.GetPendingRegistrationsAsync();
                model.PendingRegistrationsCount = pending?.Count() ?? 0;
            }
            else if (model.IsTeacher)
            {
                model.TeacherStats = await _dashboardService.GetTeacherDashboardStatsAsync(userId);
            }
            else if (model.IsStudent)
            {
                model.StudentStats = await _dashboardService.GetStudentDashboardStatsAsync(userId);
                if (userId > 0)
                {
                    model.StudentProfile = await _studentService.GetStudentByUserIdAsync(userId);
                }
            }

            return View(model);
        }
    }
}
