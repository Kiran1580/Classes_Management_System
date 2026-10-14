using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using CMS_BAL.Services.Interfaces;
using CMS_BAL.ViewModels;
using CMS_DAL.Models;
using CMS_DAL.Repositories.Interfaces;

namespace CMS_BAL.Services.Implementations
{
    public class BatchService : IBatchService
    {
        private readonly IBatchRepository _batchRepository;

        public BatchService(IBatchRepository batchRepository)
        {
            _batchRepository = batchRepository;
        }

        // ==========================================
        // Map DAL Batch -> BatchViewModel
        // ==========================================
        private static BatchViewModel Map(Batch b) => new BatchViewModel
        {
            BatchId         = b.BatchId,
            CourseId        = b.CourseId,
            CourseName      = b.CourseName,
            AcademicYearId  = b.AcademicYearId,
            AcademicYearName = b.AcademicYearName,
            BatchName       = b.BatchName,
            StartDate       = b.StartDate,
            EndDate         = b.EndDate,
            StartTime       = b.StartTime.HasValue ? b.StartTime.Value.ToString(@"hh\:mm") : null,
            EndTime         = b.EndTime.HasValue   ? b.EndTime.Value.ToString(@"hh\:mm")   : null,
            Capacity        = b.Capacity,
            RoomNo          = b.RoomNo,
            Status          = b.Status,
            CreatedAt       = b.CreatedAt,
            EnrolledCount   = b.EnrolledCount
        };

        // ==========================================
        // 1. Paged Batches
        // ==========================================
        public async Task<PagedResult<BatchViewModel>> GetBatchesAsync(
            string? search = null, int page = 1, int pageSize = 6,
            string sortBy = "BatchId", string sortOrder = "DESC",
            int? courseFilter = null, string? statusFilter = null)
        {
            page     = page < 1 ? 1 : page;
            pageSize = pageSize < 1 ? 6 : pageSize;

            var (batches, totalCount) = await _batchRepository.GetPagedBatchesAsync(
                search, page, pageSize, sortBy, sortOrder, courseFilter, statusFilter);

            return new PagedResult<BatchViewModel>
            {
                Data          = batches.Select(Map).ToList(),
                TotalCount    = totalCount,
                PageNumber    = page,
                PageSize      = pageSize,
                SearchTerm    = search,
                SortColumn    = sortBy,
                SortDirection = sortOrder
            };
        }

        // ==========================================
        // 2. All Batches (for dropdowns etc.)
        // ==========================================
        public async Task<IEnumerable<BatchViewModel>> GetAllBatchesAsync()
        {
            var batches = await _batchRepository.GetAllBatchesAsync();
            return batches.Select(Map).ToList();
        }

        // ==========================================
        // 3. Single Batch
        // ==========================================
        public async Task<BatchViewModel?> GetBatchByIdAsync(int batchId)
        {
            var batch = await _batchRepository.GetBatchByIdAsync(batchId);
            return batch == null ? null : Map(batch);
        }

        // ==========================================
        // 4. Create
        // ==========================================
        public async Task<(bool Success, string Message, int BatchId)> CreateBatchAsync(BatchViewModel model)
        {
            if (string.IsNullOrWhiteSpace(model.BatchName))
                return (false, "Batch Name is required.", 0);
            if (model.CourseId <= 0)
                return (false, "Please select a Course.", 0);
            if (model.AcademicYearId <= 0)
                return (false, "Please select an Academic Year.", 0);

            var batch = new Batch
            {
                CourseId       = model.CourseId,
                AcademicYearId = model.AcademicYearId,
                BatchName      = model.BatchName.Trim(),
                StartDate      = model.StartDate,
                EndDate        = model.EndDate,
                StartTime      = ParseTime(model.StartTime),
                EndTime        = ParseTime(model.EndTime),
                Capacity       = model.Capacity < 1 ? 50 : model.Capacity,
                RoomNo         = model.RoomNo?.Trim(),
                Status         = string.IsNullOrWhiteSpace(model.Status) ? "Active" : model.Status
            };

            int batchId = await _batchRepository.CreateBatchAsync(batch);
            if (batchId == -1) return (false, "A batch with this name already exists for the selected course and academic year.", 0);
            if (batchId <= 0)  return (false, "Failed to create batch.", 0);

            return (true, "Batch created successfully!", batchId);
        }

        // ==========================================
        // 5. Update
        // ==========================================
        public async Task<(bool Success, string Message)> UpdateBatchAsync(BatchViewModel model)
        {
            if (string.IsNullOrWhiteSpace(model.BatchName))
                return (false, "Batch Name is required.");
            if (model.CourseId <= 0)
                return (false, "Please select a Course.");
            if (model.AcademicYearId <= 0)
                return (false, "Please select an Academic Year.");

            var batch = new Batch
            {
                BatchId        = model.BatchId,
                CourseId       = model.CourseId,
                AcademicYearId = model.AcademicYearId,
                BatchName      = model.BatchName.Trim(),
                StartDate      = model.StartDate,
                EndDate        = model.EndDate,
                StartTime      = ParseTime(model.StartTime),
                EndTime        = ParseTime(model.EndTime),
                Capacity       = model.Capacity < 1 ? 50 : model.Capacity,
                RoomNo         = model.RoomNo?.Trim(),
                Status         = string.IsNullOrWhiteSpace(model.Status) ? "Active" : model.Status
            };

            int result = await _batchRepository.UpdateBatchAsync(batch);
            if (result == -1) return (false, "Another batch with this name already exists for the selected course and academic year.");
            if (result <= 0)  return (false, "Failed to update batch.");

            return (true, "Batch updated successfully!");
        }

        // ==========================================
        // 6. Delete
        // ==========================================
        public async Task<(bool Success, string Message)> DeleteBatchAsync(int batchId)
        {
            int result = await _batchRepository.DeleteBatchAsync(batchId);
            if (result == -2)
                return (false, "Cannot delete this batch because students are enrolled in it. Please transfer or remove enrolled students before deleting.");
            if (result == -3)
                return (false, "Cannot delete this batch because class sessions or attendance records are linked to it.");
            if (result == -4)
                return (false, "Cannot delete this batch because exams are associated with it.");
            if (result == -5)
                return (false, "Cannot delete this batch because study materials are linked to it.");
            if (result == 1)
                return (true, "Batch deleted successfully.");

            return (false, "Batch not found or could not be deleted.");
        }

        // ==========================================
        // 7. Stats
        // ==========================================
        public async Task<BatchStatsViewModel> GetBatchStatsAsync()
        {
            var (total, active, inactive, enrolled, coursesWithBatches) = await _batchRepository.GetBatchStatsAsync();
            return new BatchStatsViewModel
            {
                TotalBatches      = total,
                ActiveBatches     = active,
                InactiveBatches   = inactive,
                TotalEnrolled     = enrolled,
                CoursesWithBatches = coursesWithBatches
            };
        }

        // ==========================================
        // Helper: Parse "HH:mm" -> TimeSpan?
        // ==========================================
        private static TimeSpan? ParseTime(string? timeStr)
        {
            if (string.IsNullOrWhiteSpace(timeStr)) return null;
            if (TimeSpan.TryParse(timeStr, out var ts)) return ts;
            return null;
        }
    }
}
