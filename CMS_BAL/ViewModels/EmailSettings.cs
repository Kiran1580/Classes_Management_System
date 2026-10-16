namespace CMS_BAL.ViewModels
{
    public class EmailSettings
    {
        public string SmtpServer { get; set; } = "smtp-relay.brevo.com";
        public int Port { get; set; } = 587;
        public string Username { get; set; } = "be6d76001@smtp-brevo.com";
        public string Password { get; set; } = "";
        public string SenderEmail { get; set; } = "";
        public string SenderName { get; set; } = "Classes Management System";
        public string AdminNotificationEmail { get; set; } = "";
        public string BaseUrl { get; set; } = "";
        public bool EnableSsl { get; set; } = true;
    }
}
