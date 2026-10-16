using System.Security.Claims;
using System.Threading.Tasks;
using CMS_BAL.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Classes_Management_System.Controllers
{
    [Authorize]
    public class StudentCoursesController : Controller
    {
        private readonly IStudentService _studentService;

        public StudentCoursesController(IStudentService studentService)
        {
            _studentService = studentService;
        }

        [HttpGet]
        public async Task<IActionResult> Index(int? studentId = null)
        {
            int? userId = null;

            // If logged in as Student, strictly use their authenticated UserId
            if (User.IsInRole("Student"))
            {
                var claim = User.FindFirst(ClaimTypes.NameIdentifier);
                if (claim != null && int.TryParse(claim.Value, out int currentUserId))
                {
                    userId = currentUserId;
                }
                studentId = null; // Ignore any query param tampering for student users
            }
            else if (!studentId.HasValue)
            {
                // If an Admin/Teacher visits without studentId, try their userId or redirect
                var claim = User.FindFirst(ClaimTypes.NameIdentifier);
                if (claim != null && int.TryParse(claim.Value, out int currentUserId))
                {
                    userId = currentUserId;
                }
            }

            var model = await _studentService.GetStudentCoursesAndBatchesAsync(userId, studentId);
            return View(model);
        }
    }
}
