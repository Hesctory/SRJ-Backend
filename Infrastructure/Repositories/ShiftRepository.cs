using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Repositories;

public class ShiftRepository : IShiftRepository
{
    private readonly SRJDbContext _context;

    public ShiftRepository(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<(List<ShiftDTO> Items, int Total)> GetPagedAsync(int skip, int take)
    {
        var query = _context.Shifts;
        var total = await query.CountAsync();
        var items = await query
            .OrderBy(s => s.Name)
            .Skip(skip)
            .Take(take)
            .Select(s => new ShiftDTO { id = s.Id, Name = s.Name })
            .ToListAsync();
        return (items, total);
    }

    public async Task<ShiftDTO?> GetByIdAsync(int id)
    {
        return await _context.Shifts
            .Where(s => s.Id == id)
            .Select(s => new ShiftDTO { id = s.Id, Name = s.Name })
            .FirstOrDefaultAsync();
    }
}
