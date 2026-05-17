using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Queries;

public class LevelQueries : ILevelQueries
{
    private readonly SRJDbContext _context;

    public LevelQueries(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<(List<LevelDTO> Items, int Total)> GetPagedAsync(int skip, int take)
    {
        var query = _context.Levels.AsNoTracking();
        var total = await query.CountAsync();
        var items = await query
            .OrderBy(l => l.OrderIndex)
            .Skip(skip)
            .Take(take)
            .Select(l => new LevelDTO
            {
                id = l.Id,
                Name = l.Name,
                OrderIndex = l.OrderIndex
            })
            .ToListAsync();
        return (items, total);
    }

    public async Task<LevelDTO?> GetByIdAsync(int id)
    {
        return await _context.Levels
            .AsNoTracking()
            .Where(l => l.Id == id)
            .Select(l => new LevelDTO
            {
                id = l.Id,
                Name = l.Name,
                OrderIndex = l.OrderIndex
            })
            .FirstOrDefaultAsync();
    }
}
