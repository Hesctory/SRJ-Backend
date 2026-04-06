using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.Interfaces;
using SRJBackend.Domain.Entities;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Repositories;

public class AuthRepository : IAuthRepository
{
    private readonly SRJDbContext _context;

    public AuthRepository(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<DUser?> GetUserByEmailAsync(string email)
    {
        var user = await _context.Users
            .Include(u => u.Roles)
            .FirstOrDefaultAsync(u => u.Email == email);

        if (user == null) return null;

        var fullName = $"{user.Names} {user.PaternalLastname} {user.MaternalLastname}".Trim();
        var roles = user.Roles.Select(r => r.Name).ToList();
        return new DUser(user.Id, fullName, user.Email, user.Phone, user.IsActive, roles);
    }

    public async Task<string?> GetHashedPasswordByEmailAsync(string email)
    {
        var user = await _context.Users
            .FirstOrDefaultAsync(u => u.Email == email);

        return user?.HashedPassword;
    }
}
