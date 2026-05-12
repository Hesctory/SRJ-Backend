using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Repositories;

public class GradeOfferingShiftSectionRepository : IGradeOfferingShiftSectionRepository
{
    private readonly SRJDbContext _context;

    public GradeOfferingShiftSectionRepository(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<(List<SectionDTO> Items, int Total)> GetSectionsPagedAsync(int skip, int take, Dictionary<string, JsonElement>? filters = null)
    {
        var query =
            from sec in _context.GradeOfferingShiftSections
            join gs in _context.GradeOfferingShifts on sec.GradeOfferingShiftId equals gs.Id
            join go in _context.GradeOfferings on gs.GradeOfferingId equals go.Id
            join g in _context.Grades on go.GradeId equals g.Id
            select new { sec, gs, go, g };

        if (filters != null)
        {
            if (filters.TryGetValue("schoolYearId", out var schoolYearEl) && schoolYearEl.TryGetInt32(out var schoolYearId))
                query = query.Where(x => x.go.SchoolYearId == schoolYearId);

            if (filters.TryGetValue("levelId", out var levelEl) && levelEl.TryGetInt32(out var levelId))
                query = query.Where(x => x.g.LevelId == levelId);

            if (filters.TryGetValue("gradeId", out var gradeEl) && gradeEl.TryGetInt32(out var gradeId))
                query = query.Where(x => x.go.GradeId == gradeId);

            if (filters.TryGetValue("shiftId", out var shiftEl) && shiftEl.TryGetInt32(out var shiftId))
                query = query.Where(x => x.gs.ShiftId == shiftId);
        }

        var total = await query.CountAsync();
        var items = await query
            .OrderBy(x => x.sec.SectionNumber)
            .Skip(skip)
            .Take(take)
            .Select(x => new SectionDTO
            {
                id = x.sec.Id,
                Section = x.sec.Section!.Value,
                SectionNumber = x.sec.SectionNumber!.Value
            })
            .ToListAsync();

        return (items, total);
    }

    public async Task<short> GetCountByShiftAsync(int gradeOfferingShiftId)
    {
        return (short)await _context.GradeOfferingShiftSections
            .Where(sec => sec.GradeOfferingShiftId == gradeOfferingShiftId)
            .CountAsync();
    }

    public async Task AddRangeAsync(int gradeOfferingShiftId, short fromNumber, short toNumber)
    {
        var sections = new List<GradeOfferingShiftSection>();
        for (short i = fromNumber; i <= toNumber; i++)
            sections.Add(new GradeOfferingShiftSection
            {
                GradeOfferingShiftId = gradeOfferingShiftId,
                Section = (char)('A' + i - 1),
                SectionNumber = i
            });

        _context.GradeOfferingShiftSections.AddRange(sections);
        await _context.SaveChangesAsync();
    }

    public async Task RemoveAboveAsync(int gradeOfferingShiftId, short threshold)
    {
        var sections = await _context.GradeOfferingShiftSections
            .Where(sec => sec.GradeOfferingShiftId == gradeOfferingShiftId
                       && sec.SectionNumber > threshold)
            .ToListAsync();

        _context.GradeOfferingShiftSections.RemoveRange(sections);
        await _context.SaveChangesAsync();
    }

    public async Task RemoveAllByShiftAsync(int gradeOfferingShiftId)
    {
        var sections = await _context.GradeOfferingShiftSections
            .Where(sec => sec.GradeOfferingShiftId == gradeOfferingShiftId)
            .ToListAsync();

        _context.GradeOfferingShiftSections.RemoveRange(sections);
        await _context.SaveChangesAsync();
    }
}
