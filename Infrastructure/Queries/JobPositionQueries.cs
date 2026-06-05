using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Queries;

public class JobPositionQueries : IJobPositionQueries
{
    private readonly SRJDbContext _context;

    public JobPositionQueries(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<(List<JobPositionDTO> Items, int Total)> GetPagedAsync(int skip, int take, Dictionary<string, JsonElement>? filters = null)
    {
        var query = _context.JobPositions.AsNoTracking();

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
            .Select(x => new JobPositionDTO
            {
                id = x.Id,
                Name = x.Name
            })
            .ToListAsync();
        return (items, total);
    }

    public async Task<JobPositionDTO?> GetByIdAsync(int id)
    {
        return await _context.JobPositions
            .AsNoTracking()
            .Where(x => x.Id == id)
            .Select(x => new JobPositionDTO
            {
                id = x.Id,
                Name = x.Name
            })
            .FirstOrDefaultAsync();
    }
}
