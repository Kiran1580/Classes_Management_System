using System;
using System.Collections.Generic;
using System.IO;
using System.Threading.Tasks;
using CMS_BAL.Services.Interfaces;
using CMS_BAL.ViewModels;
using MailKit.Net.Smtp;
using MailKit.Security;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using MimeKit;

namespace CMS_BAL.Services.Implementations
{
    /// <summary>
    /// Centralized application-wide Email Service.
    /// Uses Brevo SMTP relay with MailKit and supports clean HTML template resolution.
    /// Adding a new email type in the application only requires adding a template in EmailTemplates/
    /// and calling SendTemplatedEmailAsync with the template name and placeholders.
    /// </summary>
    public class EmailService : IEmailService
    {
        private readonly EmailSettings _settings;
        private readonly ILogger<EmailService> _logger;

        public EmailService(IOptions<EmailSettings> settings, ILogger<EmailService> logger)
        {
            _settings = settings.Value;
            _logger = logger;
        }

        /// <summary>
        /// Single common method to send any templated email across the application.
        /// </summary>
        public async Task<bool> SendTemplatedEmailAsync(
            string toEmail,
            string subject,
            string templateName,
            IDictionary<string, string>? placeholders = null,
            string? toName = null,
            string? baseUrl = null)
        {
            if (string.IsNullOrWhiteSpace(toEmail))
            {
                _logger.LogWarning("Email recipient address is empty. Email '{Subject}' skipped.", subject);
                return false;
            }

            string effectiveBase = GetEffectiveBaseUrl(baseUrl);

            // 1. Prepare system-level standard placeholders
            var mergedPlaceholders = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
            {
                { "BaseUrl", effectiveBase },
                { "PortalUrl", !string.IsNullOrWhiteSpace(effectiveBase) ? $"{effectiveBase}/Account/Login" : "/Account/Login" },
                { "CurrentYear", DateTime.Now.Year.ToString() },
                { "CurrentDate", DateTime.Now.ToString("dd MMM yyyy") },
                { "SenderName", _settings.SenderName ?? "Classes Management System" }
            };

            // 2. Merge user-provided placeholders
            if (placeholders != null)
            {
                foreach (var kvp in placeholders)
                {
                    mergedPlaceholders[kvp.Key] = kvp.Value ?? string.Empty;
                }
            }

            // 3. Load HTML template and populate placeholders
            string htmlBody = await LoadTemplateAsync(templateName, mergedPlaceholders);
            if (string.IsNullOrWhiteSpace(htmlBody))
            {
                _logger.LogWarning("Template '{TemplateName}' content could not be loaded. Cannot send email to {ToEmail}.", templateName, toEmail);
                return false;
            }

            // 4. Send via Brevo SMTP
            return await SendEmailAsync(toEmail, subject, htmlBody, toName);
        }

        /// <summary>
        /// Common helper method to send any templated notification to the Super Administrator.
        /// </summary>
        public async Task<bool> SendAdminNotificationAsync(
            string subject,
            string templateName,
            IDictionary<string, string>? placeholders = null,
            string? baseUrl = null)
        {
            string adminEmail = (!string.IsNullOrWhiteSpace(_settings.AdminNotificationEmail) && !_settings.AdminNotificationEmail.Contains("example.com")) 
                ? _settings.AdminNotificationEmail 
                : _settings.SenderEmail;

            if (string.IsNullOrWhiteSpace(adminEmail))
            {
                _logger.LogWarning("Admin notification recipient email is not configured in appsettings.json. Notification '{Subject}' skipped.", subject);
                return false;
            }

            return await SendTemplatedEmailAsync(adminEmail, subject, templateName, placeholders, "Administrator", baseUrl);
        }

        /// <summary>
        /// Reads an HTML email template from disk and substitutes placeholders.
        /// </summary>
        public async Task<string> LoadTemplateAsync(string templateName, IDictionary<string, string>? replacements = null)
        {
            string? filePath = ResolveTemplatePath(templateName);
            if (filePath == null)
            {
                _logger.LogWarning("Email template '{TemplateName}' was not found on disk.", templateName);
                return string.Empty;
            }

            try
            {
                string content = await File.ReadAllTextAsync(filePath);
                if (replacements != null)
                {
                    foreach (var kvp in replacements)
                    {
                        content = content.Replace("{{" + kvp.Key + "}}", kvp.Value ?? string.Empty);
                    }
                }
                return content;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error reading email template '{TemplateName}' from {FilePath}", templateName, filePath);
                return string.Empty;
            }
        }

        /// <summary>
        /// Low-level direct SMTP email dispatch using MailKit and Brevo credentials.
        /// </summary>
        public async Task<bool> SendEmailAsync(string toEmail, string subject, string htmlBody, string? toName = null)
        {
            if (string.IsNullOrWhiteSpace(toEmail))
            {
                _logger.LogWarning("Email recipient address is empty. Email sending skipped.");
                return false;
            }

            if (string.IsNullOrWhiteSpace(_settings.Password) || _settings.Password.Contains("YOUR_BREVO_SMTP_KEY"))
            {
                _logger.LogWarning("SMTP Key is not configured in appsettings.json. Email '{Subject}' to {ToEmail} skipped.", subject, toEmail);
                return false;
            }

            try
            {
                var message = new MimeMessage();
                string senderEmail = string.IsNullOrWhiteSpace(_settings.SenderEmail) ? _settings.Username : _settings.SenderEmail;
                message.From.Add(new MailboxAddress(_settings.SenderName, senderEmail));
                message.To.Add(new MailboxAddress(toName ?? toEmail, toEmail));
                message.Subject = subject;

                var bodyBuilder = new BodyBuilder
                {
                    HtmlBody = htmlBody
                };
                message.Body = bodyBuilder.ToMessageBody();

                using var client = new SmtpClient();
                // Brevo relay uses Port 587 with STARTTLS
                await client.ConnectAsync(_settings.SmtpServer, _settings.Port, SecureSocketOptions.StartTls);
                await client.AuthenticateAsync(_settings.Username, _settings.Password);
                await client.SendAsync(message);
                await client.DisconnectAsync(true);

                _logger.LogInformation("Email '{Subject}' successfully sent to {ToEmail}", subject, toEmail);
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to send email '{Subject}' to {ToEmail}. Ensure Brevo SMTP credentials and authorized IP are configured.", subject, toEmail);
                return false;
            }
        }

        private string GetEffectiveBaseUrl(string? explicitBaseUrl)
        {
            if (!string.IsNullOrWhiteSpace(explicitBaseUrl))
            {
                return explicitBaseUrl.TrimEnd('/');
            }

            if (!string.IsNullOrWhiteSpace(_settings.BaseUrl))
            {
                return _settings.BaseUrl.TrimEnd('/');
            }

            return string.Empty;
        }

        private string? ResolveTemplatePath(string templateName)
        {
            string fileName = templateName.EndsWith(".html", StringComparison.OrdinalIgnoreCase) 
                ? templateName 
                : $"{templateName}.html";

            // 1. Output directory EmailTemplates (where CopyToOutputDirectory preserves it)
            string path1 = Path.Combine(AppContext.BaseDirectory, "EmailTemplates", fileName);
            if (File.Exists(path1)) return path1;

            // 2. Working directory EmailTemplates
            string path2 = Path.Combine(Directory.GetCurrentDirectory(), "EmailTemplates", fileName);
            if (File.Exists(path2)) return path2;

            // 3. Project folder EmailTemplates during development
            string path3 = Path.Combine(Directory.GetCurrentDirectory(), "Classes_Management_System", "EmailTemplates", fileName);
            if (File.Exists(path3)) return path3;

            return null;
        }
    }
}
