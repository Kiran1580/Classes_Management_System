using System.Security.Claims;

namespace Classes_Management_System.Common
{
    public static class PermissionExtensions
    {
        public static bool HasPermission(this ClaimsPrincipal user, string permissionKey)
        {
            if (user == null || user.Identity?.IsAuthenticated != true)
                return false;

            if (user.IsInRole("Admin"))
                return true;

            return user.HasClaim("Permission", permissionKey);
        }
    }
}
