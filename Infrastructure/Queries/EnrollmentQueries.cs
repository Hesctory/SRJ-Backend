using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Domain.Constants;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Queries;

public class EnrollmentQueries : IEnrollmentQueries
{
    private readonly SRJDbContext _context;

    public EnrollmentQueries(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<List<EnrollmentSummaryDTO>> GetByStudentAsync(int studentId)
    {
        return await (
            from e in _context.Enrollments
            where e.StudentId == studentId
            join sy in _context.SchoolYears on e.SchoolYearId equals sy.Id
            join s in _context.GradeOfferingShiftSections on e.GradeOfferingShiftSectionId equals s.Id
            join gs in _context.GradeOfferingShifts on s.GradeOfferingShiftId equals gs.Id
            join sh in _context.Shifts on gs.ShiftId equals sh.Id
            join go in _context.GradeOfferings on gs.GradeOfferingId equals go.Id
            join g in _context.Grades on go.GradeId equals g.Id
            join l in _context.Levels on g.LevelId equals l.Id
            join st in _context.EnrollmentStates on e.StateId equals st.Id
            orderby e.Id
            select new EnrollmentSummaryDTO
            {
                Id = e.Id,
                Year = sy.Year,
                Level = l.Name,
                Grade = g.Name,
                Shift = sh.Name,
                Section = s.Section,
                State = st.Name!
            }
        ).ToListAsync();
    }

    public async Task<EnrollmentDTO?> GetByIdAsync(int id)
    {
        return await RawQuery()
            .Where(e => e.Id == id)
            .FirstOrDefaultAsync();
    }

    public async Task<EnrollmentDTO?> GetLatestByStudentAsync(int studentId)
    {
        return await RawQuery()
            .Where(e => e.StudentId == studentId)
            .OrderByDescending(e => e.Id)
            .FirstOrDefaultAsync();
    }

    public async Task<bool> HasValidEnrollmentsAsync(int studentId)
    {
        var validStateIds = await _context.EnrollmentStates
            .Where(s => s.Name != EnrollmentStateNames.Cancelled)
            .Select(s => s.Id)
            .ToListAsync();

        return await _context.Enrollments
            .AnyAsync(e => e.StudentId == studentId && validStateIds.Contains(e.StateId));
    }

    private IQueryable<EnrollmentDTO> RawQuery() =>
        from e in _context.Enrollments
        join s in _context.GradeOfferingShiftSections on e.GradeOfferingShiftSectionId equals s.Id
        join gs in _context.GradeOfferingShifts on s.GradeOfferingShiftId equals gs.Id
        join go in _context.GradeOfferings on gs.GradeOfferingId equals go.Id
        join g in _context.Grades on go.GradeId equals g.Id
        select new EnrollmentDTO
        {
            Id = e.Id,
            Code = e.Code,
            CodeNumber = e.CodeNumber,
            StudentId = e.StudentId,
            LevelId = g.LevelId,
            GradeId = go.GradeId,
            ShiftId = gs.ShiftId,
            SectionId = s.Id,
            SchoolFeeConceptId = e.SchoolFeeConceptId,
            SchoolYearId = e.SchoolYearId,
            PreviousSchool = e.PreviousSchool
        };
}
