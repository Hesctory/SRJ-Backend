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

    public async Task<List<SectionDTO>> GetAllAsync(int? gradeOfferingShiftId = null)
    {
        var query = _context.GradeOfferingShiftSections.AsQueryable();

        if (gradeOfferingShiftId.HasValue)
            query = query.Where(sec => sec.GradeOfferingShiftId == gradeOfferingShiftId.Value);

        return await query
            .Select(sec => new SectionDTO
            {
                Id = sec.Id,
                Name = "Section " + sec.Section,
                GradeOfferingShiftId = sec.GradeOfferingShiftId
            })
            .ToListAsync();
    }
}
