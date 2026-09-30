// Please see documentation at https://learn.microsoft.com/aspnet/core/client-side/bundling-and-minification
// for details on configuring this project to bundle and minify static web assets.

// Write your JavaScript code.
window.changeGridPageSize = function (selectElem, pageSizeParam, pageParam) {
    if (!selectElem) return;
    var newPageSize = selectElem.value;
    var currentUrl = new URL(window.location.href);
    currentUrl.searchParams.set(pageSizeParam || 'pageSize', newPageSize);
    currentUrl.searchParams.set(pageParam || 'page', '1');
    window.location.href = currentUrl.toString();
};
