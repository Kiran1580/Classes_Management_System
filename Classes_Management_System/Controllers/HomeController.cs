using System.Security.Claims;
using Microsoft.AspNetCore.Mvc;

namespace Classes_Management_System.Controllers
{
    public class HomeController : Controller
    {
        public IActionResult Index()
        {
            if (User.Identity?.IsAuthenticated == true)
            {
                var role = User.FindFirstValue(ClaimTypes.Role);
                return role switch
                {
                    "Admin" => RedirectToAction("Index", "Dashboard", new { area = "Admin" }),
                    "Teacher" => RedirectToAction("Index", "Dashboard", new { area = "Teacher" }),
                    "Student" => RedirectToAction("Index", "Dashboard", new { area = "Student" }),
                    _ => RedirectToAction("Login", "Account")
                };
            }

            return RedirectToAction("Login", "Account");
        }

        public IActionResult Error()
        {
            return View();
        }
    }
}
