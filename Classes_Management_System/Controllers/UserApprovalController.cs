using System;
using System.Collections.Generic;
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
        private readonly IEmailService _emailService;

        public UserApprovalController(IAuthService authService, IEmailService emailService)
        {
            _authService = authService;
            _emailService = emailService;
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
            // Fetch applicant details before approval to prepare email dispatch
            var user = await _authService.GetUserByIdAsync(id);

            var (success, message) = await _authService.ApproveUserAsync(id);
            if (success)
            {
                TempData["SuccessMessage"] = message;

                // Send Approval Email asynchronously in background
                if (user != null && !string.IsNullOrWhiteSpace(user.Email))
                {
                    string baseUrl = $"{Request.Scheme}://{Request.Host}";
                    string userEmail = user.Email;
                    string userName = user.FullName;
                    string userRole = user.RoleName;

                    _ = Task.Run(async () =>
                    {
                        try
                        {
                            string loginUrl = $"{baseUrl}/Account/Login";
                            string approvalDate = DateTime.Now.ToString("dd MMM yyyy, hh:mm tt");

                            if (string.Equals(userRole, "Teacher", StringComparison.OrdinalIgnoreCase))
                            {
                                await _emailService.SendTemplatedEmailAsync(
                                    toEmail: userEmail,
                                    subject: "🎉 Congratulations! Your Faculty Account Has Been Approved",
                                    templateName: "TeacherApprovalNotification",
                                    placeholders: new Dictionary<string, string>
                                    {
                                        { "TeacherName", userName },
                                        { "TeacherEmail", userEmail },
                                        { "SubjectSpecialization", "Faculty Staff" },
                                        { "ApprovalDate", approvalDate },
                                        { "LoginUrl", loginUrl }
                                    },
                                    toName: userName,
                                    baseUrl: baseUrl);
                            }
                            else
                            {
                                // Student
                                await _emailService.SendTemplatedEmailAsync(
                                    toEmail: userEmail,
                                    subject: "🎉 Congratulations! Your Student Admission Has Been Approved",
                                    templateName: "StudentApprovalNotification",
                                    placeholders: new Dictionary<string, string>
                                    {
                                        { "StudentName", userName },
                                        { "StudentEmail", userEmail },
                                        { "ApprovalDate", approvalDate },
                                        { "LoginUrl", loginUrl }
                                    },
                                    toName: userName,
                                    baseUrl: baseUrl);
                            }
                        }
                        catch
                        {
                            // Error logging handled inside EmailService
                        }
                    });
                }
            }
            else
            {
                TempData["ErrorMessage"] = message;
            }

            if (!string.IsNullOrWhiteSpace(returnRole) && !string.Equals(returnRole, "All", StringComparison.OrdinalIgnoreCase))
            {
                return RedirectToAction(nameof(Index), new { role = returnRole });
            }

            return RedirectToAction(nameof(Index));
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Reject(int id, string? reason = null, string? returnRole = null)
        {
            // Fetch applicant details before rejection (since rejection removes the record from DB)
            var user = await _authService.GetUserByIdAsync(id);

            var (success, message) = await _authService.RejectUserAsync(id);
            if (success)
            {
                TempData["SuccessMessage"] = message;

                // Send Rejection Notice Email asynchronously in background
                if (user != null && !string.IsNullOrWhiteSpace(user.Email))
                {
                    string baseUrl = $"{Request.Scheme}://{Request.Host}";
                    string userEmail = user.Email;
                    string userName = user.FullName;
                    string userRole = user.RoleName;
                    string effectiveReason = !string.IsNullOrWhiteSpace(reason) 
                        ? reason.Trim() 
                        : "Application details did not meet the standard verification or eligibility criteria.";

                    _ = Task.Run(async () =>
                    {
                        try
                        {
                            await _emailService.SendTemplatedEmailAsync(
                                toEmail: userEmail,
                                subject: "Update Regarding Your Registration Application - Classes Management System",
                                templateName: "UserRejectionNotification",
                                placeholders: new Dictionary<string, string>
                                {
                                    { "FullName", userName },
                                    { "RoleName", userRole },
                                    { "Reason", effectiveReason },
                                    { "DecisionDate", DateTime.Now.ToString("dd MMM yyyy") }
                                },
                                toName: userName,
                                baseUrl: baseUrl);
                        }
                        catch
                        {
                            // Error logging handled inside EmailService
                        }
                    });
                }
            }
            else
            {
                TempData["ErrorMessage"] = message;
            }

            if (!string.IsNullOrWhiteSpace(returnRole) && !string.Equals(returnRole, "All", StringComparison.OrdinalIgnoreCase))
            {
                return RedirectToAction(nameof(Index), new { role = returnRole });
            }

            return RedirectToAction(nameof(Index));
        }
    }
}
