using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Queries;

public class GradeQueries : IGradeQueries
{
    private readonly SRJDbContext _context;

    public GradeQueries(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<(List<GradeDTO> Items, int Total)> GetPagedAsync(int skip, int take, Dictionary<string, JsonElement>? filters = null)
    {
        var query = _context.Grades.AsNoTracking();

        if (filters != null)
        {
            if (filters.TryGetValue("levelId", out var levelIdEl) && levelIdEl.TryGetInt32(out var levelId))
                query = query.Where(g => g.LevelId == levelId);

            if (filters.TryGetValue("name", out var nameEl) && nameEl.GetString() is string name)
                query = query.Where(g => g.Name.ToLower().Contains(name.ToLower()));

            if (filters.TryGetValue("year", out var yearEl) && yearEl.TryGetInt32(out var year))
                query = query.Where(g => g.Year == year);

            if (filters.TryGetValue("id", out var idEl) && idEl.ValueKind == JsonValueKind.Array)
            {
                var ids = idEl.EnumerateArray()
                    .Where(e => e.TryGetInt32(out _))
                    .Select(e => e.GetInt32())
                    .ToList();
                query = query.Where(g => ids.Contains(g.Id));
            }

            if (filters.TryGetValue("schoolYearId", out var syEl) && syEl.TryGetInt32(out var schoolYearId))
                query = query.Where(g => g.GradeOfferings.Any(go => go.SchoolYearId == schoolYearId));
        }

        var total = await query.CountAsync();
        var items = await query
            .OrderBy(g => g.LevelId)
            .ThenBy(g => g.Year)
            .Skip(skip)
            .Take(take)
            .Select(g => new GradeDTO
            {
                id = g.Id,
                LevelId = g.LevelId,
                Name = g.Name,
                Year = g.Year
            })
            .ToListAsync();
        return (items, total);
    }

    public async Task<GradeDTO?> GetByIdAsync(int id)
    {
        return await _context.Grades
            .AsNoTracking()
            .Where(g => g.Id == id)
            .Select(g => new GradeDTO
            {
                id = g.Id,
                LevelId = g.LevelId,
                Name = g.Name,
                Year = g.Year
            })
            .FirstOrDefaultAsync();
    }
}
