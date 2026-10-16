using System.Collections.Generic;
using System.Threading.Tasks;

namespace CMS_BAL.Services.Interfaces
{
    /// <summary>
    /// Generic, application-wide email service interface.
    /// Supports sending any templated HTML email by simply creating an HTML template file
    /// in the EmailTemplates folder and providing the placeholder key-values.
    /// </summary>
    public interface IEmailService
    {
        /// <summary>
        /// Common generic method to send any templated email across the entire application.
        /// Simply specify the recipient email, subject, template name (from EmailTemplates folder),
        /// and a dictionary of placeholders (e.g. {{StudentName}}, {{Amount}}, etc.).
        /// </summary>
        Task<bool> SendTemplatedEmailAsync(
            string toEmail,
            string subject,
            string templateName,
            IDictionary<string, string>? placeholders = null,
            string? toName = null,
            string? baseUrl = null);

        /// <summary>
        /// Common helper to send any templated notification to the Administrator.
        /// Automatically resolves the Admin email configured in appsettings.json.
        /// </summary>
        Task<bool> SendAdminNotificationAsync(
            string subject,
            string templateName,
            IDictionary<string, string>? placeholders = null,
            string? baseUrl = null);

        /// <summary>
        /// Direct HTML email sending without using a template file.
        /// </summary>
        Task<bool> SendEmailAsync(string toEmail, string subject, string htmlBody, string? toName = null);

        /// <summary>
        /// Reads an HTML email template from disk and replaces {{Key}} with Value.
        /// </summary>
        Task<string> LoadTemplateAsync(string templateName, IDictionary<string, string>? replacements = null);
    }
}
