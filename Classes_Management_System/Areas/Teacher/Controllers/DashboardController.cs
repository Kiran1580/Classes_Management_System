using System;
using System.Security.Claims;
using System.Threading.Tasks;
using CMS_BAL.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Classes_Management_System.Areas.Teacher.Controllers
{
    [Area("Teacher")]
    [Authorize(Roles = "Teacher")]
    public class DashboardController : Controller
    {
        private readonly IDashboardService _dashboardService;

        public DashboardController(IDashboardService dashboardService)
        {
            _dashboardService = dashboardService;
        }

        public async Task<IActionResult> Index()
        {
            var userIdClaim = User.FindFirstValue(ClaimTypes.NameIdentifier);
            int userId = int.TryParse(userIdClaim, out int id) ? id : 0;

            var stats = await _dashboardService.GetTeacherDashboardStatsAsync(userId);
            return View(stats);
        }
    }
}
