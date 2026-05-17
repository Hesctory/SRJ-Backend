using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.Interfaces;
using SRJBackend.Domain.Entities;
using SRJBackend.Domain.ValueObjects;

using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Repositories;

public class EnrollmentRepository : IEnrollmentRepository
{
    private readonly SRJDbContext _context;

    public EnrollmentRepository(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<DEnrollment> CreateAsync(int studentId, AcademicPlacement placement, int schoolFeeConceptId, int schoolYearId, string? previousSchool = null)
    {
        await _context.Database.ExecuteSqlRawAsync("SELECT pg_advisory_xact_lock({0})", schoolYearId);

        var syModel = await _context.SchoolYears.FindAsync(schoolYearId)
            ?? throw new KeyNotFoundException("Año escolar no encontrado.");
        var schoolYear = DSchoolYear.Reconstitute(syModel.Id, syModel.Year, syModel.StartDate, syModel.EndDate, syModel.IsActive == true);

        var maxCodeNumber = await _context.Enrollments
            .Where(e => e.SchoolYearId == schoolYearId)
            .MaxAsync(e => (int?)e.CodeNumber) ?? 0;

        var enrollmentCode = EnrollmentCode.Generate(schoolYear.Year, maxCodeNumber);
        var domain = DEnrollment.Create(enrollmentCode, studentId, placement, schoolFeeConceptId, schoolYear, previousSchool);

        var enrollment = new Enrollment
        {
            Code = domain.Code.Code,
            CodeNumber = domain.Code.CodeNumber,
            GradeOfferingShiftSectionId = domain.Placement.SectionId,
            StudentId = domain.StudentId,
            SchoolFeeConceptId = domain.SchoolFeeConceptId,
            SchoolYearId = domain.SchoolYearId,
            PreviousSchool = domain.PreviousSchool
        };

        _context.Enrollments.Add(enrollment);
        await _context.SaveChangesAsync();

        return DEnrollment.Reconstitute(enrollment.Id, enrollmentCode, studentId, placement,
            enrollment.SchoolFeeConceptId, enrollment.SchoolYearId, enrollment.PreviousSchool);
    }

    public async Task<List<DEnrollment>> GetByStudentIdAsync(int studentId)
    {
        var rows = await JoinedEnrollments()
            .Where(r => r.StudentId == studentId)
            .OrderBy(r => r.Id)
            .ToListAsync();

        return rows.Select(ToDomain).ToList();
    }

    public async Task<DEnrollment?> GetLatestByStudentIdAsync(int studentId)
    {
        var row = await JoinedEnrollments()
            .Where(r => r.StudentId == studentId)
            .OrderByDescending(r => r.Id)
            .FirstOrDefaultAsync();

        return row == null ? null : ToDomain(row);
    }

    public async Task<DEnrollment?> GetByStudentIdAndYearAsync(int studentId, int schoolYearId)
    {
        var row = await JoinedEnrollments()
            .Where(r => r.StudentId == studentId && r.SchoolYearId == schoolYearId)
            .FirstOrDefaultAsync();

        return row == null ? null : ToDomain(row);
    }

    public async Task<DEnrollment?> GetByIdAsync(int id)
    {
        var row = await JoinedEnrollments()
            .Where(r => r.Id == id)
            .FirstOrDefaultAsync();

        return row == null ? null : ToDomain(row);
    }

    public async Task<DEnrollment> UpdateAsync(int id, AcademicPlacement placement, int schoolFeeConceptId, string? previousSchool)
    {
        var enrollment = await _context.Enrollments.FindAsync(id)
            ?? throw new KeyNotFoundException("Matrícula no encontrada.");

        var syModel = await _context.SchoolYears.FindAsync(enrollment.SchoolYearId)
            ?? throw new KeyNotFoundException("Año escolar no encontrado.");

        var schoolYear = DSchoolYear.Reconstitute(syModel.Id, syModel.Year, syModel.StartDate, syModel.EndDate, syModel.IsActive == true);

        var row = await JoinedEnrollments().Where(r => r.Id == id).FirstOrDefaultAsync()
            ?? throw new KeyNotFoundException("Matrícula no encontrada.");

        var domain = ToDomain(row);
        domain.Update(placement, schoolFeeConceptId, schoolYear, previousSchool);

        enrollment.GradeOfferingShiftSectionId = domain.Placement.SectionId;
        enrollment.SchoolFeeConceptId = domain.SchoolFeeConceptId;
        enrollment.PreviousSchool = domain.PreviousSchool;

        await _context.SaveChangesAsync();
        return domain;
    }

    public async Task<bool> DeleteAsync(int id)
    {
        var enrollment = await _context.Enrollments.FindAsync(id);
        if (enrollment == null) return false;

        var syModel = await _context.SchoolYears.FindAsync(enrollment.SchoolYearId)
            ?? throw new KeyNotFoundException("Año escolar no encontrado.");

        var schoolYear = DSchoolYear.Reconstitute(syModel.Id, syModel.Year, syModel.StartDate, syModel.EndDate, syModel.IsActive == true);

        var domain = await GetByIdAsync(id) ?? throw new KeyNotFoundException("Matrícula no encontrada.");
        domain.ValidateCanDelete(schoolYear);

        _context.Enrollments.Remove(enrollment);
        await _context.SaveChangesAsync();
        return true;
    }

    private IQueryable<EnrollmentRow> JoinedEnrollments() =>
        from e in _context.Enrollments
        join s in _context.GradeOfferingShiftSections on e.GradeOfferingShiftSectionId equals s.Id
        join gs in _context.GradeOfferingShifts on s.GradeOfferingShiftId equals gs.Id
        join go in _context.GradeOfferings on gs.GradeOfferingId equals go.Id
        join g in _context.Grades on go.GradeId equals g.Id
        select new EnrollmentRow
        {
            Id = e.Id,
            Code = e.Code,
            CodeNumber = e.CodeNumber,
            StudentId = e.StudentId!.Value,
            LevelId = g.LevelId,
            GradeId = go.GradeId,
            ShiftId = gs.ShiftId,
            SectionId = s.Id,
            SchoolFeeConceptId = e.SchoolFeeConceptId,
            SchoolYearId = e.SchoolYearId,
            PreviousSchool = e.PreviousSchool
        };

    private static DEnrollment ToDomain(EnrollmentRow r) =>
        DEnrollment.Reconstitute(
            r.Id,
            new EnrollmentCode(r.Code, r.CodeNumber),
            r.StudentId,
            new AcademicPlacement(r.LevelId, r.GradeId, r.ShiftId, r.SectionId),
            r.SchoolFeeConceptId,
            r.SchoolYearId,
            r.PreviousSchool);

    private class EnrollmentRow
    {
        public int Id { get; set; }
        public string Code { get; set; } = null!;
        public int CodeNumber { get; set; }
        public int StudentId { get; set; }
        public int LevelId { get; set; }
        public int GradeId { get; set; }
        public int ShiftId { get; set; }
        public int SectionId { get; set; }
        public int SchoolFeeConceptId { get; set; }
        public int SchoolYearId { get; set; }
        public string? PreviousSchool { get; set; }
    }
}
