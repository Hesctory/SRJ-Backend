using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Domain.Constants;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Queries;

public class BillingDataQueries : IBillingDataQueries
{
    private readonly SRJDbContext _context;

    public BillingDataQueries(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<SchoolFeeAmounts?> GetFeesAsync(int schoolYearId, int levelId, int shiftId, int schoolFeeConceptId)
    {
        return await _context.SchoolFees
            .AsNoTracking()
            .Where(f => f.SchoolYearId == schoolYearId
                     && f.LevelId == levelId
                     && f.ShiftId == shiftId
                     && f.SchoolFeeConceptId == schoolFeeConceptId)
            .Select(f => new SchoolFeeAmounts(f.RegistrationFee, f.EnrollmentPrice, f.TuitionCost))
            .FirstOrDefaultAsync();
    }

    public async Task<IReadOnlyList<SchoolYearMonthInfo>> GetSchoolYearMonthsAsync(int schoolYearId)
    {
        return await _context.SchoolYearMonths
            .AsNoTracking()
            .Where(m => m.SchoolYearId == schoolYearId)
            .OrderBy(m => m.Month)
            .Select(m => new SchoolYearMonthInfo(m.Month, m.DueDate))
            .ToListAsync();
    }

    public async Task<int> GetYearAsync(int schoolYearId)
    {
        return await _context.SchoolYears
            .Where(sy => sy.Id == schoolYearId)
            .Select(sy => sy.Year)
            .FirstOrDefaultAsync();
    }

    public async Task<IReadOnlyList<BillingEnrollment>> GetActiveEnrollmentsForBillingAsync(int year)
    {
        return await (
            from e in _context.Enrollments
            join sy in _context.SchoolYears on e.SchoolYearId equals sy.Id
            join st in _context.EnrollmentStates on e.StateId equals st.Id
            join goss in _context.GradeOfferingShiftSections on e.GradeOfferingShiftSectionId equals goss.Id
            join gos in _context.GradeOfferingShifts on goss.GradeOfferingShiftId equals gos.Id
            join go in _context.GradeOfferings on gos.GradeOfferingId equals go.Id
            join g in _context.Grades on go.GradeId equals g.Id
            // is_active gates which year the school is operating; the calendar-year match is the
            // tie-breaker when next-year pre-registration is also active (August onward).
            where sy.IsActive == true && sy.Year == year && st.Name == EnrollmentStateNames.Active
            select new BillingEnrollment(
                e.Id,
                e.StudentId,
                e.SchoolYearId,
                sy.Year,
                g.LevelId,
                gos.ShiftId,
                e.SchoolFeeConceptId))
            .AsNoTracking()
            .ToListAsync();
    }
}
