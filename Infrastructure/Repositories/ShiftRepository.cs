using System.Text.Json;
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

    public async Task<(List<ShiftDTO> Items, int Total)> GetPagedAsync(int skip, int take, Dictionary<string, JsonElement>? filters = null)
    {
        var query = _context.Shifts.AsQueryable();

        var opts = new JsonSerializerOptions { WriteIndented = true };
        Console.WriteLine($"=== GET /api/shifts | filters={JsonSerializer.Serialize(filters)} ===");

        if (filters != null)
        {
            int? schoolYearId = filters.TryGetValue("schoolYearId", out var syEl) && syEl.TryGetInt32(out var sy) ? sy : null;
            int? levelId      = filters.TryGetValue("levelId",      out var lvEl) && lvEl.TryGetInt32(out var lv) ? lv : null;
            int? gradeId      = filters.TryGetValue("gradeId",      out var grEl) && grEl.TryGetInt32(out var gr) ? gr : null;

            if (schoolYearId.HasValue || gradeId.HasValue)
            {
                query = query.Where(s => s.GradeOfferingShifts.Any(gos =>
                    (!schoolYearId.HasValue || gos.GradeOffering.SchoolYearId == schoolYearId.Value) &&
                    (!gradeId.HasValue      || gos.GradeOffering.GradeId == gradeId.Value)
                ));

                var afterAll = await query.Select(s => new ShiftDTO { id = s.Id, Name = s.Name }).ToListAsync();
                Console.WriteLine($"After combined filters (schoolYearId={schoolYearId}, levelId={levelId}, gradeId={gradeId}): {JsonSerializer.Serialize(afterAll, opts)}");
            }
        }

        var total = await query.CountAsync();
        var items = await query
            .OrderBy(s => s.Name)
            .Skip(skip)
            .Take(take)
            .Select(s => new ShiftDTO { id = s.Id, Name = s.Name })
            .ToListAsync();
        Console.WriteLine($"Final ({items.Count}/{total}): {JsonSerializer.Serialize(items, opts)}");
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
