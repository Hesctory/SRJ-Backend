using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Queries;

public class GradeOfferingQueries : IGradeOfferingQueries
{
    private readonly SRJDbContext _context;

    public GradeOfferingQueries(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<(List<GradeOfferingDTO> Items, int Total)> GetPagedAsync(int skip, int take, Dictionary<string, JsonElement>? filters = null)
    {
        var query = _context.GradeOfferingShifts.AsNoTracking();

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

            if (filters.TryGetValue("gradeId", out var gradeIdEl) && gradeIdEl.TryGetInt32(out var gradeId))
                query = query.Where(s => s.GradeOffering.GradeId == gradeId);

            if (filters.TryGetValue("schoolYearId", out var schoolYearIdEl) && schoolYearIdEl.TryGetInt32(out var schoolYearId))
                query = query.Where(s => s.GradeOffering.SchoolYearId == schoolYearId);

            if (filters.TryGetValue("shiftId", out var shiftIdEl) && shiftIdEl.TryGetInt32(out var shiftId))
                query = query.Where(s => s.ShiftId == shiftId);
        }

        var total = await query.CountAsync();
        var items = await query
            .OrderBy(s => s.GradeOffering.SchoolYearId)
            .ThenBy(s => s.GradeOffering.GradeId)
            .Skip(skip)
            .Take(take)
            .Select(s => new GradeOfferingDTO
            {
                id = s.Id,
                GradeId = s.GradeOffering.GradeId,
                SchoolYearId = s.GradeOffering.SchoolYearId,
                ShiftId = s.ShiftId,
                Sections = s.Sections
            })
            .ToListAsync();
        return (items, total);
    }

    public async Task<GradeOfferingDTO?> GetByIdAsync(int id)
    {
        return await _context.GradeOfferingShifts
            .AsNoTracking()
            .Where(s => s.Id == id)
            .Select(s => new GradeOfferingDTO
            {
                id = s.Id,
                GradeId = s.GradeOffering.GradeId,
                SchoolYearId = s.GradeOffering.SchoolYearId,
                ShiftId = s.ShiftId,
                Sections = s.Sections
            })
            .FirstOrDefaultAsync();
    }
}
