using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.Authorization;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Authorization;

public class PermissionAuthorizationHandler : AuthorizationHandler<PermissionRequirement>
{
    private readonly SRJDbContext _context;

    public PermissionAuthorizationHandler(SRJDbContext context)
    {
        _context = context;
    }

    protected override async Task HandleRequirementAsync(
        AuthorizationHandlerContext context,
        PermissionRequirement requirement)
    {
        var roleNames = context.User
            .FindAll(ClaimTypes.Role)
            .Select(c => c.Value)
            .ToList();

        if (roleNames.Count == 0) return;

        var hasPermission = await _context.Roles
            .Where(r => roleNames.Contains(r.Name))
            .AnyAsync(r => r.Permissions.Any(p => p.Name == requirement.Permission));

        if (hasPermission)
            context.Succeed(requirement);
    }
}
