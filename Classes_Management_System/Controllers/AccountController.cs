using System.Security.Claims;
using CMS_BAL.Services.Interfaces;
using CMS_BAL.ViewModels;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Classes_Management_System.Controllers
{
    public class AccountController : Controller
    {
        private readonly IAuthService _authService;
        private readonly IEmailService _emailService;

        public AccountController(IAuthService authService, IEmailService emailService)
        {
            _authService = authService;
            _emailService = emailService;
        }

        [HttpGet]
        [AllowAnonymous]
        public IActionResult Login(string? returnUrl = null)
        {
            if (User.Identity?.IsAuthenticated == true)
            {
                return RedirectUserByRole();
            }

            ViewData["ReturnUrl"] = returnUrl;
            return View(new LoginViewModel { ReturnUrl = returnUrl });
        }

        [HttpPost]
        [AllowAnonymous]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Login(LoginViewModel model)
        {
            if (!ModelState.IsValid)
            {
                return View(model);
            }

            var (success, message, user) = await _authService.ValidateUserAsync(model);

            if (!success || user == null)
            {
                ModelState.AddModelError(string.Empty, message);
                return View(model);
            }

            // Create Claims for Cookie Auth
            var claims = new List<Claim>
            {
                new Claim(ClaimTypes.NameIdentifier, user.UserId.ToString()),
                new Claim(ClaimTypes.Name, user.FullName),
                new Claim(ClaimTypes.Email, user.Email),
                new Claim(ClaimTypes.Role, user.RoleName),
                new Claim("RoleId", user.RoleId.ToString())
            };

            // Fetch and attach RBAC Permission Claims
            var permissions = await _authService.GetUserPermissionsAsync(user.UserId);
            foreach (var perm in permissions)
            {
                claims.Add(new Claim("Permission", perm));
            }

            var claimsIdentity = new ClaimsIdentity(claims, CookieAuthenticationDefaults.AuthenticationScheme);
            var authProperties = new AuthenticationProperties
            {
                IsPersistent = model.RememberMe,
                ExpiresUtc = model.RememberMe ? DateTimeOffset.UtcNow.AddDays(30) : DateTimeOffset.UtcNow.AddHours(8)
            };

            await HttpContext.SignInAsync(
                CookieAuthenticationDefaults.AuthenticationScheme,
                new ClaimsPrincipal(claimsIdentity),
                authProperties);

            if (!string.IsNullOrWhiteSpace(model.ReturnUrl) && Url.IsLocalUrl(model.ReturnUrl))
            {
                return Redirect(model.ReturnUrl);
            }

            return RedirectUserByRole(user.RoleName);
        }

        [HttpGet]
        [AllowAnonymous]
        public IActionResult RegisterStudent()
        {
            if (User.Identity?.IsAuthenticated == true)
            {
                return RedirectUserByRole();
            }
            return View(new StudentRegisterViewModel());
        }

        [HttpPost]
        [AllowAnonymous]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> RegisterStudent(StudentRegisterViewModel model)
        {
            if (!ModelState.IsValid)
            {
                return View(model);
            }

            var (success, message) = await _authService.RegisterStudentAsync(model);
            if (!success)
            {
                ModelState.AddModelError(string.Empty, message);
                return View(model);
            }

            // Capture live domain/host dynamically before running in background
            string baseUrl = $"{Request.Scheme}://{Request.Host}";

            // Send notification emails asynchronously in background (won't block UI / fail registration)
            _ = Task.Run(async () =>
            {
                try
                {
                    // 1. Notify Administrator
                    await _emailService.SendAdminNotificationAsync(
                        subject: $"📢 New Student Registration: {model.FullName}",
                        templateName: "AdminNewStudentNotification",
                        placeholders: new Dictionary<string, string>
                        {
                            { "StudentName", model.FullName },
                            { "StudentEmail", model.Email },
                            { "StudentMobile", model.Mobile ?? "—" },
                            { "ParentName", model.ParentName ?? "—" },
                            { "ParentMobile", model.ParentMobile ?? "—" },
                            { "ApprovalUrl", $"{baseUrl}/UserApproval" },
                            { "RegistrationDate", DateTime.Now.ToString("dd MMM yyyy, hh:mm tt") }
                        },
                        baseUrl: baseUrl);

                    // 2. Acknowledge Student
                    await _emailService.SendTemplatedEmailAsync(
                        toEmail: model.Email,
                        subject: "Welcome! Your Registration Application Has Been Received",
                        templateName: "StudentRegistrationAcknowledgment",
                        placeholders: new Dictionary<string, string>
                        {
                            { "StudentName", model.FullName },
                            { "StudentEmail", model.Email },
                            { "RegistrationDate", DateTime.Now.ToString("dd MMM yyyy") }
                        },
                        toName: model.FullName,
                        baseUrl: baseUrl);
                }
                catch
                {
                    // Email logging is safely handled within EmailService
                }
            });

            TempData["SuccessMessage"] = message;
            return RedirectToAction(nameof(Login));
        }

        [HttpGet]
        [AllowAnonymous]
        public IActionResult RegisterTeacher()
        {
            if (User.Identity?.IsAuthenticated == true)
            {
                return RedirectUserByRole();
            }
            return View(new TeacherRegisterViewModel());
        }

        [HttpPost]
        [AllowAnonymous]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> RegisterTeacher(TeacherRegisterViewModel model)
        {
            if (!ModelState.IsValid)
            {
                return View(model);
            }

            var (success, message) = await _authService.RegisterTeacherAsync(model);
            if (!success)
            {
                ModelState.AddModelError(string.Empty, message);
                return View(model);
            }

            // Capture live domain/host dynamically before running in background
            string baseUrl = $"{Request.Scheme}://{Request.Host}";

            // Send notification emails asynchronously in background
            _ = Task.Run(async () =>
            {
                try
                {
                    // 1. Notify Administrator
                    await _emailService.SendAdminNotificationAsync(
                        subject: $"🔔 New Faculty Application: {model.FullName}",
                        templateName: "AdminNewTeacherNotification",
                        placeholders: new Dictionary<string, string>
                        {
                            { "TeacherName", model.FullName },
                            { "TeacherEmail", model.Email },
                            { "TeacherMobile", model.Mobile ?? "—" },
                            { "Qualification", model.Qualification ?? "—" },
                            { "SubjectSpecialization", model.SubjectSpecialization ?? "—" },
                            { "ApprovalUrl", $"{baseUrl}/UserApproval?role=Teacher" },
                            { "RegistrationDate", DateTime.Now.ToString("dd MMM yyyy, hh:mm tt") }
                        },
                        baseUrl: baseUrl);

                    // 2. Acknowledge Teacher
                    await _emailService.SendTemplatedEmailAsync(
                        toEmail: model.Email,
                        subject: "Welcome! Your Faculty Registration Has Been Received",
                        templateName: "TeacherRegistrationAcknowledgment",
                        placeholders: new Dictionary<string, string>
                        {
                            { "TeacherName", model.FullName },
                            { "TeacherEmail", model.Email },
                            { "Qualification", model.Qualification ?? "—" },
                            { "SubjectSpecialization", model.SubjectSpecialization ?? "—" },
                            { "RegistrationDate", DateTime.Now.ToString("dd MMM yyyy, hh:mm tt") }
                        },
                        toName: model.FullName,
                        baseUrl: baseUrl);
                }
                catch
                {
                    // Email logging is safely handled within EmailService
                }
            });

            TempData["SuccessMessage"] = message;
            return RedirectToAction(nameof(Login));
        }

        [HttpPost]
        [HttpGet]
        public async Task<IActionResult> Logout()
        {
            await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
            return RedirectToAction(nameof(Login));
        }

        [HttpGet]
        [AllowAnonymous]
        public IActionResult AccessDenied()
        {
            return View();
        }

        private IActionResult RedirectUserByRole(string? role = null)
        {
            return RedirectToAction("Index", "Dashboard");
        }
    }
}
