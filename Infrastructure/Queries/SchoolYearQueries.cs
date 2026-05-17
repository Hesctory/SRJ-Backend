using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Queries;

public class SchoolYearQueries : ISchoolYearQueries
{
    private readonly SRJDbContext _context;

    public SchoolYearQueries(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<(List<SchoolYearDTO> Items, int Total)> GetPagedAsync(int skip, int take, Dictionary<string, JsonElement>? filters = null)
    {
        var query = _context.SchoolYears.AsNoTracking();

        if (filters != null)
        {
            if (filters.TryGetValue("id", out var idEl) && idEl.ValueKind == JsonValueKind.Array)
            {
                var ids = idEl.EnumerateArray()
                    .Where(e => e.TryGetInt32(out _))
                    .Select(e => e.GetInt32())
                    .ToList();
                query = query.Where(s => ids.Contains(s.Id));
            }

            if (filters.TryGetValue("year", out var yearEl) && yearEl.TryGetInt16(out var year))
                query = query.Where(s => s.Year == year);

            if (filters.TryGetValue("isActive", out var isActiveEl) && (isActiveEl.ValueKind == JsonValueKind.True || isActiveEl.ValueKind == JsonValueKind.False))
                query = query.Where(s => s.IsActive == isActiveEl.GetBoolean());
        }

        var total = await query.CountAsync();
        var items = await query
            .OrderBy(s => s.Year)
            .Skip(skip)
            .Take(take)
            .Select(s => new SchoolYearDTO
            {
                id = s.Id,
                Year = s.Year,
                StartDate = s.StartDate,
                EndDate = s.EndDate,
                IsActive = s.IsActive
            })
            .ToListAsync();
        return (items, total);
    }

    public async Task<SchoolYearDTO?> GetByIdAsync(int id)
    {
        return await _context.SchoolYears
            .AsNoTracking()
            .Where(s => s.Id == id)
            .Select(s => new SchoolYearDTO
            {
                id = s.Id,
                Year = s.Year,
                StartDate = s.StartDate,
                EndDate = s.EndDate,
                IsActive = s.IsActive
            })
            .FirstOrDefaultAsync();
    }
}
