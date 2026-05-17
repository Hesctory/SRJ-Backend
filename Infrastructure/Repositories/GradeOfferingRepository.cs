using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Repositories;

public class GradeOfferingRepository : IGradeOfferingRepository
{
    private readonly SRJDbContext _context;
    private readonly IGradeOfferingShiftSectionRepository _sectionRepository;

    public GradeOfferingRepository(SRJDbContext context, IGradeOfferingShiftSectionRepository sectionRepository)
    {
        _context = context;
        _sectionRepository = sectionRepository;
    }

    public async Task<bool> ExistsAsync(int id)
    {
        return await _context.GradeOfferingShifts.AnyAsync(s => s.Id == id);
    }

    public async Task<int> CreateAsync(CreateGradeOfferingDTO dto)
    {
        var offering = await _context.GradeOfferings
            .FirstOrDefaultAsync(o => o.GradeId == dto.GradeId && o.SchoolYearId == dto.SchoolYearId);

        if (offering == null)
        {
            offering = new GradeOffering { GradeId = dto.GradeId, SchoolYearId = dto.SchoolYearId };
            _context.GradeOfferings.Add(offering);
            await _context.SaveChangesAsync();
        }

        var shift = new GradeOfferingShift
        {
            GradeOfferingId = offering.Id,
            ShiftId = dto.ShiftId,
            Sections = dto.Sections
        };
        _context.GradeOfferingShifts.Add(shift);
        await _context.SaveChangesAsync();

        if (dto.Sections > 0)
            await _sectionRepository.AddRangeAsync(shift.Id, 1, dto.Sections);
        
        return shift.Id;
    }

    public async Task UpdateAsync(int id, CreateGradeOfferingDTO dto)
    {
        var shift = await _context.GradeOfferingShifts
            .Include(s => s.GradeOffering)
            .FirstOrDefaultAsync(s => s.Id == id);

        var oldSections = shift!.Sections ?? 0;
        shift.ShiftId = dto.ShiftId;
        shift.Sections = dto.Sections;

        if (shift.GradeOffering.GradeId != dto.GradeId || shift.GradeOffering.SchoolYearId != dto.SchoolYearId)
        {
            var offering = await _context.GradeOfferings
                .FirstOrDefaultAsync(o => o.GradeId == dto.GradeId && o.SchoolYearId == dto.SchoolYearId);

            if (offering == null)
            {
                offering = new GradeOffering { GradeId = dto.GradeId, SchoolYearId = dto.SchoolYearId };
                _context.GradeOfferings.Add(offering);
                await _context.SaveChangesAsync();
            }

            shift.GradeOfferingId = offering.Id;
        }

        await _context.SaveChangesAsync();

        if (dto.Sections > oldSections)
            await _sectionRepository.AddRangeAsync(id, (short)(oldSections + 1), dto.Sections);
        else if (dto.Sections < oldSections)
            await _sectionRepository.RemoveAboveAsync(id, dto.Sections);
    }

    public async Task<bool> DeleteAsync(int id)
    {
        var shift = await _context.GradeOfferingShifts
            .FirstOrDefaultAsync(s => s.Id == id);

        if (shift == null) return false;

        await _sectionRepository.RemoveAllByShiftAsync(id);

        var offeringId = shift.GradeOfferingId;
        _context.GradeOfferingShifts.Remove(shift);
        await _context.SaveChangesAsync();

        var hasOtherShifts = await _context.GradeOfferingShifts.AnyAsync(s => s.GradeOfferingId == offeringId);
        if (!hasOtherShifts)
        {
            var offering = await _context.GradeOfferings.FindAsync(offeringId);
            if (offering != null)
            {
                _context.GradeOfferings.Remove(offering);
                await _context.SaveChangesAsync();
            }
        }

        return true;
    }
}
