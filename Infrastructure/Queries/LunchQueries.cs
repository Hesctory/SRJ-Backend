using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Queries;

public class LunchQueries : ILunchQueries
{
    private readonly SRJDbContext _context;

    public LunchQueries(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<(List<LunchDTO> Items, int Total)> GetPagedAsync(int skip, int take, Dictionary<string, JsonElement>? filters = null)
    {
        var query = _context.Lunches.AsNoTracking();

        var total = await query.CountAsync();
        var items = await query
            .OrderBy(x => x.Id)
            .Skip(skip)
            .Take(take)
            .Select(x => new LunchDTO
            {
                id = x.Id,
                LunchCategoryId = x.LunchCategoryId,
                LunchCategoryName = x.LunchCategory.Name,
                LunchName = x.LunchName,
                CostPrice = x.CostPrice,
                SalePrice = x.SalePrice,
                Comment = x.Comment
            })
            .ToListAsync();
        return (items, total);
    }

    public async Task<LunchDTO?> GetByIdAsync(int id)
    {
        return await _context.Lunches
            .AsNoTracking()
            .Where(x => x.Id == id)
            .Select(x => new LunchDTO
            {
                id = x.Id,
                LunchCategoryId = x.LunchCategoryId,
                LunchCategoryName = x.LunchCategory.Name,
                LunchName = x.LunchName,
                CostPrice = x.CostPrice,
                SalePrice = x.SalePrice,
                Comment = x.Comment
            })
            .FirstOrDefaultAsync();
    }
}
