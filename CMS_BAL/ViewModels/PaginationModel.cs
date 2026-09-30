using System;
using System.Collections.Generic;

namespace CMS_BAL.ViewModels
{
    /// <summary>
    /// Simple generic paged result: { Data: [...], TotalCount: N, ... }
    /// </summary>
    public class PagedResult<T>
    {
        public List<T> Data { get; set; } = new List<T>();
        public int TotalCount { get; set; }
        public int PageNumber { get; set; } = 1;
        public int PageSize { get; set; } = 6;
        public string? SearchTerm { get; set; }
        public string? SortColumn { get; set; }
        public string? SortDirection { get; set; }

        public int TotalPages => PageSize > 0 ? (int)Math.Ceiling((double)TotalCount / PageSize) : 0;
        public int StartItem => TotalCount == 0 ? 0 : ((PageNumber - 1) * PageSize) + 1;
        public int EndItem => Math.Min(PageNumber * PageSize, TotalCount);
        public bool HasPreviousPage => PageNumber > 1;
        public bool HasNextPage => PageNumber < TotalPages;
    }
}
