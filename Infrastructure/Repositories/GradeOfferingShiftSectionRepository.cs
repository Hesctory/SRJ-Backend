using Microsoft.EntityFrameworkCore;
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

    public async Task<int?> FindValidSectionIdAsync(int schoolYearId, int gradeId, int shiftId, int sectionId)
    {
        var exists = await (
            from s in _context.GradeOfferingShiftSections
            join gs in _context.GradeOfferingShifts on s.GradeOfferingShiftId equals gs.Id
            join go in _context.GradeOfferings on gs.GradeOfferingId equals go.Id
            where s.Id == sectionId
               && gs.ShiftId == shiftId
               && go.GradeId == gradeId
               && go.SchoolYearId == schoolYearId
            select s.Id
        ).AnyAsync();

        return exists ? sectionId : null;
    }
}
