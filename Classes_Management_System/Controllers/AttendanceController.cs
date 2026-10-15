using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Claims;
using System.Text;
using System.Threading.Tasks;
using Classes_Management_System.Models;
using CMS_BAL.Services.Interfaces;
using CMS_DAL.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Classes_Management_System.Controllers
{
    [Authorize]
    public class AttendanceController : Controller
    {
        private readonly IAttendanceService _attendanceService;
        private readonly IBatchService _batchService;
        private readonly ICourseService _courseService;
        private readonly ITeacherService _teacherService;
        private readonly IStudentService _studentService;

        public AttendanceController(
            IAttendanceService attendanceService,
            IBatchService batchService,
            ICourseService courseService,
            ITeacherService teacherService,
            IStudentService studentService)
        {
            _attendanceService = attendanceService;
            _batchService = batchService;
            _courseService = courseService;
            _teacherService = teacherService;
            _studentService = studentService;
        }

        private int GetCurrentUserId()
        {
            var claim = User.FindFirst(ClaimTypes.NameIdentifier);
            return claim != null && int.TryParse(claim.Value, out int id) ? id : 0;
        }

        // ==========================================================
        // 1. Master Attendance Grid (Admin & Teacher Views)
        // ==========================================================
        [HttpGet]
        public async Task<IActionResult> Index(
            string? searchTerm,
            int? batchId,
            int? courseId,
            DateTime? fromDate,
            DateTime? toDate,
            string? status,
            int pageNumber = 1,
            int pageSize = 10,
            string sortColumn = "SessionDate",
            string sortDirection = "DESC")
        {
            if (User.IsInRole("Student"))
            {
                return RedirectToAction(nameof(MyAttendance));
            }

            int? filterTeacherId = null;
            if (User.IsInRole("Teacher") && !User.IsInRole("Admin"))
            {
                var teacher = await _teacherService.GetTeacherByUserIdAsync(GetCurrentUserId());
                if (teacher != null)
                {
                    filterTeacherId = teacher.TeacherId;
                }
            }

            var pagedResult = await _attendanceService.GetPagedAttendanceRecordsAsync(
                searchTerm, batchId, courseId, fromDate, toDate, status,
                filterTeacherId, pageNumber, pageSize, sortColumn, sortDirection);

            var stats = await _attendanceService.GetAttendanceDashboardStatsAsync(filterTeacherId);
            var courses = await _courseService.GetAllCoursesAsync();
            List<AttendanceBatchOption> batchOptions;

            if (filterTeacherId.HasValue)
            {
                var assigned = await _teacherService.GetTeacherBatchesAsync(filterTeacherId.Value);
                if (assigned != null && assigned.Any())
                {
                    batchOptions = assigned.Select(a => new AttendanceBatchOption
                    {
                        BatchId = a.BatchId,
                        BatchName = $"{a.BatchName} ({a.CourseName})"
                    }).DistinctBy(b => b.BatchId).ToList();
                }
                else
                {
                    batchOptions = new List<AttendanceBatchOption>();
                }
            }
            else
            {
                var allB = await _batchService.GetAllBatchesAsync();
                batchOptions = allB?.Select(b => new AttendanceBatchOption
                {
                    BatchId = b.BatchId,
                    BatchName = b.BatchName
                }).ToList() ?? new List<AttendanceBatchOption>();
            }

            var courseOptions = courses?.Select(c => new AttendanceCourseOption
            {
                CourseId = c.CourseId,
                CourseName = c.CourseName
            }).ToList() ?? new List<AttendanceCourseOption>();

            var viewModel = new AttendanceIndexViewModel
            {
                Records = pagedResult.Items,
                TotalCount = pagedResult.TotalCount,
                TotalPresent = pagedResult.TotalPresent,
                TotalAbsent = pagedResult.TotalAbsent,
                TotalLate = pagedResult.TotalLate,
                Stats = stats,
                Batches = batchOptions,
                Courses = courseOptions,
                SearchTerm = searchTerm,
                BatchId = batchId,
                CourseId = courseId,
                FromDate = fromDate,
                ToDate = toDate,
                Status = status,
                PageNumber = pageNumber,
                PageSize = pageSize,
                SortColumn = sortColumn,
                SortDirection = sortDirection
            };

            return View(viewModel);
        }

        // ==========================================================
        // 2. Daily Attendance Marking Sheet (Teacher & Admin)
        // ==========================================================
        [HttpGet]
        [Authorize(Roles = "Admin,Teacher")]
        public async Task<IActionResult> Mark(int? batchId, DateTime? sessionDate, int? subjectId)
        {
            var date = sessionDate?.Date ?? DateTime.Today;
            var isTeacher = User.IsInRole("Teacher") && !User.IsInRole("Admin");
            int? teacherId = null;
            string? teacherName = null;
            List<AttendanceBatchOption> availableBatches = new List<AttendanceBatchOption>();

            if (isTeacher)
            {
                var teacher = await _teacherService.GetTeacherByUserIdAsync(GetCurrentUserId());
                if (teacher != null)
                {
                    teacherId = teacher.TeacherId;
                    teacherName = teacher.FullName;
                    var assigned = await _teacherService.GetTeacherBatchesAsync(teacher.TeacherId);
                    if (assigned != null && assigned.Any())
                    {
                        availableBatches = assigned.Select(a => new AttendanceBatchOption
                        {
                            BatchId = a.BatchId,
                            BatchName = $"{a.BatchName} ({a.CourseName} - {a.SubjectName})"
                        }).DistinctBy(b => b.BatchId).ToList();
                    }
                }
            }
            else
            {
                var allBatches = await _batchService.GetAllBatchesAsync();
                availableBatches = allBatches?.Where(b => b.Status == "Active").Select(b => new AttendanceBatchOption
                {
                    BatchId = b.BatchId,
                    BatchName = $"{b.BatchName} ({b.CourseName})"
                }).ToList() ?? new List<AttendanceBatchOption>();
            }

            // Auto-select first batch if not selected
            int selectedBatchId = batchId ?? (availableBatches.FirstOrDefault()?.BatchId ?? 0);
            List<AttendanceStudentItem> students = new List<AttendanceStudentItem>();
            string? existingTopic = null;

            if (selectedBatchId > 0)
            {
                var roster = await _attendanceService.GetStudentsForAttendanceAsync(selectedBatchId, date, subjectId);
                students = roster?.ToList() ?? new List<AttendanceStudentItem>();
                existingTopic = students.FirstOrDefault()?.Topic;
            }

            var vm = new MarkAttendanceViewModel
            {
                SelectedBatchId = selectedBatchId,
                SelectedDate = date,
                SelectedSubjectId = subjectId,
                Topic = existingTopic,
                AvailableBatches = availableBatches,
                Students = students,
                IsTeacher = isTeacher,
                TeacherId = teacherId,
                TeacherName = teacherName
            };

            return View(vm);
        }

        // ==========================================================
        // 3. AJAX: Load Roster for Selected Batch & Date
        // ==========================================================
        [HttpGet]
        [Authorize(Roles = "Admin,Teacher")]
        public async Task<IActionResult> GetRoster(int batchId, DateTime sessionDate, int? subjectId)
        {
            if (batchId <= 0)
                return Json(new { success = false, message = "Please select a valid batch." });

            var students = await _attendanceService.GetStudentsForAttendanceAsync(batchId, sessionDate.Date, subjectId);
            var studentList = students?.ToList() ?? new List<AttendanceStudentItem>();
            var first = studentList.FirstOrDefault();

            return Json(new
            {
                success = true,
                students = studentList,
                topic = first?.Topic ?? string.Empty,
                isAlreadyMarked = first?.IsAlreadyMarked ?? false
            });
        }

        // ==========================================================
        // 4. AJAX: Save Batch Attendance (Single/Bulk Submit)
        // ==========================================================
        [HttpPost]
        [Authorize(Roles = "Admin,Teacher")]
        public async Task<IActionResult> SaveAttendance([FromBody] SaveBatchAttendanceRequest request)
        {
            if (request == null || request.BatchId <= 0)
            {
                return Json(new { success = false, message = "Invalid attendance data provided." });
            }

            if (request.Students == null || !request.Students.Any())
            {
                return Json(new { success = false, message = "No students selected for attendance." });
            }

            if (request.SessionDate.Date > DateTime.Today.AddDays(1))
            {
                return Json(new { success = false, message = "Future date attendance is not allowed." });
            }

            // Assign teacher ID if current user is teacher
            if (User.IsInRole("Teacher") && !User.IsInRole("Admin"))
            {
                var teacher = await _teacherService.GetTeacherByUserIdAsync(GetCurrentUserId());
                if (teacher != null)
                {
                    request.TeacherId = teacher.TeacherId;
                }
            }

            try
            {
                var result = await _attendanceService.SaveBatchAttendanceAsync(request);
                return Json(new
                {
                    success = true,
                    message = $"Attendance saved successfully for {result.TotalMarked} student(s)!",
                    sessionId = result.SessionId,
                    totalMarked = result.TotalMarked
                });
            }
            catch (Exception ex)
            {
                return Json(new { success = false, message = "Failed to save attendance: " + ex.Message });
            }
        }

        // ==========================================================
        // 5. Student Self-Tracking: My Attendance Portal
        // ==========================================================
        [HttpGet]
        public async Task<IActionResult> MyAttendance(
            DateTime? fromDate,
            DateTime? toDate,
            string? status,
            int pageNumber = 1,
            int pageSize = 10,
            string sortColumn = "SessionDate",
            string sortDirection = "DESC")
        {
            var student = await _studentService.GetStudentByUserIdAsync(GetCurrentUserId());
            if (student == null)
            {
                // If admin is viewing or student profile not linked
                if (User.IsInRole("Admin"))
                {
                    return RedirectToAction(nameof(Index));
                }

                TempData["ErrorMessage"] = "Student profile not found. Please contact administration.";
                return RedirectToAction("Index", "Dashboard");
            }

            var pagedResult = await _attendanceService.GetPagedStudentAttendanceAsync(
                student.StudentId, fromDate, toDate, status, pageNumber, pageSize, sortColumn, sortDirection);

            var vm = new StudentAttendanceViewModel
            {
                StudentId = student.StudentId,
                StudentName = student.FullName,
                AdmissionNo = student.AdmissionNo,
                ProfileImage = student.ProfileImage,
                TotalClasses = pagedResult.TotalClasses,
                AttendedClasses = pagedResult.AttendedClasses,
                AbsentClasses = pagedResult.AbsentClasses,
                LateClasses = pagedResult.LateClasses,
                AttendancePercentage = pagedResult.AttendancePercentage,
                Records = pagedResult.Items,
                TotalCount = pagedResult.TotalCount,
                FromDate = fromDate,
                ToDate = toDate,
                Status = status,
                PageNumber = pageNumber,
                PageSize = pageSize,
                SortColumn = sortColumn,
                SortDirection = sortDirection
            };

            return View(vm);
        }

        // ==========================================================
        // 6. Export Attendance Records to CSV (Admin/Teacher)
        // ==========================================================
        [HttpGet]
        [Authorize(Roles = "Admin,Teacher")]
        public async Task<IActionResult> ExportCsv(
            string? searchTerm,
            int? batchId,
            int? courseId,
            DateTime? fromDate,
            DateTime? toDate,
            string? status)
        {
            int? filterTeacherId = null;
            if (User.IsInRole("Teacher") && !User.IsInRole("Admin"))
            {
                var teacher = await _teacherService.GetTeacherByUserIdAsync(GetCurrentUserId());
                if (teacher != null) filterTeacherId = teacher.TeacherId;
            }

            // Export all matching records (up to 5000)
            var paged = await _attendanceService.GetPagedAttendanceRecordsAsync(
                searchTerm, batchId, courseId, fromDate, toDate, status,
                filterTeacherId, 1, 5000, "SessionDate", "DESC");

            var sb = new StringBuilder();
            sb.AppendLine("Date,Admission No,Student Name,Batch,Course,Subject,Faculty,Status,Remarks,Topic");

            foreach (var r in paged.Items)
            {
                sb.AppendLine($"\"{r.SessionDate:yyyy-MM-dd}\",\"{r.AdmissionNo}\",\"{r.StudentName}\",\"{r.BatchName}\",\"{r.CourseName}\",\"{r.SubjectName}\",\"{r.TeacherName}\",\"{r.Status}\",\"{r.Remarks}\",\"{r.Topic}\"");
            }

            var bytes = Encoding.UTF8.GetBytes(sb.ToString());
            var fileName = $"Attendance_Report_{DateTime.Now:yyyyMMdd_HHmm}.csv";
            return File(bytes, "text/csv", fileName);
        }
    }
}
