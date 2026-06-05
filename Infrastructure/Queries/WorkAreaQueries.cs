using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Queries;

public class WorkAreaQueries : IWorkAreaQueries
{
    private readonly SRJDbContext _context;

    public WorkAreaQueries(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<(List<WorkAreaDTO> Items, int Total)> GetPagedAsync(int skip, int take, Dictionary<string, JsonElement>? filters = null)
    {
        var query = _context.WorkAreas.AsNoTracking();

        if (filters != null)
        {
            if (filters.TryGetValue("name", out var nameEl) && nameEl.GetString() is string name)
                query = query.Where(x => x.Name.ToLower().Contains(name.ToLower()));
        }

        var total = await query.CountAsync();
        var items = await query
            .OrderBy(x => x.Name)
            .Skip(skip)
            .Take(take)
            .Select(x => new WorkAreaDTO
            {
                id = x.Id,
                Name = x.Name
            })
            .ToListAsync();
        return (items, total);
    }

    public async Task<WorkAreaDTO?> GetByIdAsync(int id)
    {
        return await _context.WorkAreas
            .AsNoTracking()
            .Where(x => x.Id == id)
            .Select(x => new WorkAreaDTO
            {
                id = x.Id,
                Name = x.Name
            })
            .FirstOrDefaultAsync();
    }
}
