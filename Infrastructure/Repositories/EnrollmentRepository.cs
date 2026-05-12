using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.Interfaces;
using SRJBackend.Domain.Entities;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Repositories;

public class EnrollmentRepository : IEnrollmentRepository
{
    private readonly SRJDbContext _context;

    public EnrollmentRepository(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<int?> FindSectionIdAsync(int schoolYearId, int gradeId, int shiftId, int sectionId)
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

    public async Task<DEnrollment> CreateAsync(int studentId, int sectionId, int schoolFeeConceptId, int schoolYearId, string? previousSchool = null)
    {
        var ownedTransaction = _context.Database.CurrentTransaction == null
            ? await _context.Database.BeginTransactionAsync()
            : null;

        try
        {
            await _context.Database.ExecuteSqlRawAsync("SELECT pg_advisory_xact_lock({0})", schoolYearId);

            var schoolYear = await _context.SchoolYears.FindAsync(schoolYearId)
                ?? throw new KeyNotFoundException("Año escolar no encontrado.");

            if (schoolYear.IsActive != true)
                throw new InvalidOperationException("No se puede matricular en un año escolar que no está activo.");

            var maxCodeNumber = await _context.Enrollments
                .Where(e => e.SchoolYearId == schoolYearId)
                .MaxAsync(e => (int?)e.CodeNumber) ?? 0;

            var codeNumber = maxCodeNumber + 1;
            var code = $"{schoolYear.Year}-{codeNumber:D6}";

            var enrollment = new Enrollment
            {
                Code = code,
                CodeNumber = codeNumber,
                GradeOfferingShiftSectionId = sectionId,
                StudentId = studentId,
                SchoolFeeConceptId = schoolFeeConceptId,
                SchoolYearId = schoolYearId,
                PreviousSchool = previousSchool
            };

            _context.Enrollments.Add(enrollment);
            await _context.SaveChangesAsync();

            if (ownedTransaction != null)
                await ownedTransaction.CommitAsync();

            return new DEnrollment(enrollment.Id, enrollment.Code, enrollment.CodeNumber,
                                   enrollment.StudentId!.Value, enrollment.GradeOfferingShiftSectionId,
                                   enrollment.SchoolFeeConceptId, enrollment.SchoolYearId, enrollment.PreviousSchool);
        }
        catch
        {
            if (ownedTransaction != null)
                await ownedTransaction.RollbackAsync();
            throw;
        }
    }

    public async Task<List<DEnrollment>> GetByStudentIdAsync(int studentId)
    {
        return await _context.Enrollments
            .Where(e => e.StudentId == studentId)
            .OrderBy(e => e.Id)
            .Select(e => new DEnrollment(e.Id, e.Code, e.CodeNumber, e.StudentId!.Value, e.GradeOfferingShiftSectionId, e.SchoolFeeConceptId, e.SchoolYearId, e.PreviousSchool))
            .ToListAsync();
    }

    public async Task<DEnrollment?> GetLatestByStudentIdAsync(int studentId)
    {
        var e = await _context.Enrollments
            .Where(e => e.StudentId == studentId)
            .OrderByDescending(e => e.Id)
            .FirstOrDefaultAsync();

        return e == null ? null : new DEnrollment(e.Id, e.Code, e.CodeNumber, e.StudentId!.Value, e.GradeOfferingShiftSectionId, e.SchoolFeeConceptId, e.SchoolYearId, e.PreviousSchool);
    }

    public async Task<DEnrollment?> GetByStudentIdAndYearAsync(int studentId, int schoolYearId)
    {
        var e = await _context.Enrollments
            .Where(e => e.StudentId == studentId && e.SchoolYearId == schoolYearId)
            .FirstOrDefaultAsync();

        return e == null ? null : new DEnrollment(e.Id, e.Code, e.CodeNumber, e.StudentId!.Value, e.GradeOfferingShiftSectionId, e.SchoolFeeConceptId, e.SchoolYearId, e.PreviousSchool);
    }
}
