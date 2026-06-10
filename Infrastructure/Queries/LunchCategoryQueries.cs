using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Queries;

public class LunchCategoryQueries : ILunchCategoryQueries
{
    private readonly SRJDbContext _context;

    public LunchCategoryQueries(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<(List<LunchCategoryDTO> Items, int Total)> GetPagedAsync(int skip, int take, Dictionary<string, JsonElement>? filters = null)
    {
        var query = _context.LunchCategories.AsNoTracking();

        var total = await query.CountAsync();
        var items = await query
            .OrderBy(x => x.Name)
            .Skip(skip)
            .Take(take)
            .Select(x => new LunchCategoryDTO
            {
                id = x.Id,
                Name = x.Name
            })
            .ToListAsync();
        return (items, total);
    }

    public async Task<LunchCategoryDTO?> GetByIdAsync(int id)
    {
        return await _context.LunchCategories
            .AsNoTracking()
            .Where(x => x.Id == id)
            .Select(x => new LunchCategoryDTO
            {
                id = x.Id,
                Name = x.Name
            })
            .FirstOrDefaultAsync();
    }
}
