using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Queries;

public class AccountQueries : IAccountQueries
{
    private readonly SRJDbContext _context;

    public AccountQueries(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<(List<AccountDTO> Items, int Total)> GetPagedAsync(int skip, int take, Dictionary<string, JsonElement>? filters = null)
    {
        var query = _context.Accounts.AsNoTracking();

        if (filters != null)
        {
            if (filters.TryGetValue("parentAccountId", out var parentEl))
            {
                if (parentEl.ValueKind == JsonValueKind.Null)
                    query = query.Where(a => a.ParentAccountId == null);
                else if (parentEl.TryGetInt32(out var parentId))
                    query = query.Where(a => a.ParentAccountId == parentId);
            }

            if (filters.TryGetValue("code", out var codeEl) && codeEl.GetString() is string code)
                query = query.Where(a => a.Code.ToLower().Contains(code.ToLower()));

            if (filters.TryGetValue("name", out var nameEl) && nameEl.GetString() is string name)
                query = query.Where(a => a.Name.ToLower().Contains(name.ToLower()));

            if (filters.TryGetValue("id", out var idEl) && idEl.ValueKind == JsonValueKind.Array)
            {
                var ids = idEl.EnumerateArray()
                    .Where(e => e.TryGetInt32(out _))
                    .Select(e => e.GetInt32())
                    .ToList();
                query = query.Where(a => ids.Contains(a.Id));
            }
        }

        var total = await query.CountAsync();
        var items = await query
            .OrderBy(a => a.Code)
            .Skip(skip)
            .Take(take)
            .Select(a => new AccountDTO
            {
                id = a.Id,
                Code = a.Code,
                Name = a.Name,
                ParentAccountId = a.ParentAccountId,
                PrintCode = a.PrintCode
            })
            .ToListAsync();

        return (items, total);
    }

    public async Task<AccountDTO?> GetByIdAsync(int id)
    {
        return await _context.Accounts
            .AsNoTracking()
            .Where(a => a.Id == id)
            .Select(a => new AccountDTO
            {
                id = a.Id,
                Code = a.Code,
                Name = a.Name,
                ParentAccountId = a.ParentAccountId,
                PrintCode = a.PrintCode
            })
            .FirstOrDefaultAsync();
    }
}
