using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Queries;

public class ShiftQueries : IShiftQueries
{
    private readonly SRJDbContext _context;

    public ShiftQueries(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<(List<ShiftDTO> Items, int Total)> GetPagedAsync(int skip, int take, Dictionary<string, JsonElement>? filters = null)
    {
        var query = _context.Shifts.AsNoTracking();

        if (filters != null)
        {
            int? schoolYearId = filters.TryGetValue("schoolYearId", out var syEl) && syEl.TryGetInt32(out var sy) ? sy : null;
            int? gradeId      = filters.TryGetValue("gradeId",      out var grEl) && grEl.TryGetInt32(out var gr) ? gr : null;

            if (schoolYearId.HasValue || gradeId.HasValue)
                query = query.Where(s => s.GradeOfferingShifts.Any(gos =>
                    (!schoolYearId.HasValue || gos.GradeOffering.SchoolYearId == schoolYearId.Value) &&
                    (!gradeId.HasValue      || gos.GradeOffering.GradeId == gradeId.Value)
                ));
        }

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
            .AsNoTracking()
            .Where(s => s.Id == id)
            .Select(s => new ShiftDTO { id = s.Id, Name = s.Name })
            .FirstOrDefaultAsync();
    }
}
