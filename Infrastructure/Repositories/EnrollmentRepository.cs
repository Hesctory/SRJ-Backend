using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.Interfaces;
using SRJBackend.Domain.Constants;
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

    public async Task<DEnrollment> CreateAsync(int studentId, AcademicPlacement placement, int schoolFeeConceptId, int schoolYearId, string? previousSchool = null, bool isNew = false)
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
            PreviousSchool = domain.PreviousSchool,
            EnrollmentDate = domain.EnrollmentDate,
            Isnew = isNew
        };

        _context.Enrollments.Add(enrollment);
        await _context.SaveChangesAsync();

        return DEnrollment.Reconstitute(enrollment.Id, enrollmentCode, studentId, placement,
            enrollment.SchoolFeeConceptId, enrollment.SchoolYearId, enrollment.PreviousSchool,
            enrollment.EnrollmentDate, EnrollmentStatus.Active);
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

    public async Task<bool> CancelAsync(int id)
    {
        var loaded = await LoadForStateTransitionAsync(id);
        if (loaded == null) return false;
        var (ef, domain, schoolYear) = loaded.Value;

        domain.Cancel(schoolYear);
        ef.StateId = await GetStateIdAsync(EnrollmentStateNames.Cancelled);
        await _context.SaveChangesAsync();
        return true;
    }

    public async Task<bool> WithdrawAsync(int id)
    {
        var loaded = await LoadForStateTransitionAsync(id);
        if (loaded == null) return false;
        var (ef, domain, schoolYear) = loaded.Value;

        domain.Withdraw(schoolYear);
        ef.StateId = await GetStateIdAsync(EnrollmentStateNames.Withdrawn);
        await _context.SaveChangesAsync();
        return true;
    }

    public async Task<bool> ReactivateAsync(int id)
    {
        var loaded = await LoadForStateTransitionAsync(id);
        if (loaded == null) return false;
        var (ef, domain, schoolYear) = loaded.Value;

        domain.Reactivate(schoolYear);
        ef.StateId = await GetStateIdAsync(EnrollmentStateNames.Active);
        await _context.SaveChangesAsync();
        return true;
    }

    private async Task<(Enrollment EfModel, DEnrollment Domain, DSchoolYear SchoolYear)?> LoadForStateTransitionAsync(int id)
    {
        var row = await (
            from e in _context.Enrollments
            join sy in _context.SchoolYears on e.SchoolYearId equals sy.Id
            join s in _context.GradeOfferingShiftSections on e.GradeOfferingShiftSectionId equals s.Id
            join gs in _context.GradeOfferingShifts on s.GradeOfferingShiftId equals gs.Id
            join go in _context.GradeOfferings on gs.GradeOfferingId equals go.Id
            join g in _context.Grades on go.GradeId equals g.Id
            join st in _context.EnrollmentStates on e.StateId equals st.Id
            where e.Id == id
            select new
            {
                EfModel = e,
                SyId = sy.Id, SyYear = sy.Year, SyStart = sy.StartDate, SyEnd = sy.EndDate, SyActive = sy.IsActive,
                LevelId = g.LevelId, GradeId = go.GradeId, ShiftId = gs.ShiftId, SectionId = s.Id,
                EnrollmentDate = e.EnrollmentDate,
                StateName = st.Name ?? string.Empty
            }
        ).FirstOrDefaultAsync();

        if (row == null) return null;

        var schoolYear = DSchoolYear.Reconstitute(row.SyId, row.SyYear, row.SyStart, row.SyEnd, row.SyActive == true);
        var domainRow = new EnrollmentRow
        {
            Id = row.EfModel.Id,
            Code = row.EfModel.Code,
            CodeNumber = row.EfModel.CodeNumber,
            StudentId = row.EfModel.StudentId,
            LevelId = row.LevelId,
            GradeId = row.GradeId,
            ShiftId = row.ShiftId,
            SectionId = row.SectionId,
            SchoolFeeConceptId = row.EfModel.SchoolFeeConceptId,
            SchoolYearId = row.EfModel.SchoolYearId,
            PreviousSchool = row.EfModel.PreviousSchool,
            EnrollmentDate = row.EnrollmentDate,
            StateName = row.StateName
        };

        return (row.EfModel, ToDomain(domainRow), schoolYear);
    }

    private async Task<int> GetStateIdAsync(string name)
    {
        var id = await _context.EnrollmentStates
            .Where(s => s.Name == name)
            .Select(s => s.Id)
            .FirstOrDefaultAsync();
        if (id == 0) throw new KeyNotFoundException($"Estado '{name}' no encontrado en la base de datos.");
        return id;
    }

    private IQueryable<EnrollmentRow> JoinedEnrollments() =>
        from e in _context.Enrollments
        join s in _context.GradeOfferingShiftSections on e.GradeOfferingShiftSectionId equals s.Id
        join gs in _context.GradeOfferingShifts on s.GradeOfferingShiftId equals gs.Id
        join go in _context.GradeOfferings on gs.GradeOfferingId equals go.Id
        join g in _context.Grades on go.GradeId equals g.Id
        join st in _context.EnrollmentStates on e.StateId equals st.Id
        select new EnrollmentRow
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
            PreviousSchool = e.PreviousSchool,
            EnrollmentDate = e.EnrollmentDate,
            StateName = st.Name ?? string.Empty
        };

    private static DEnrollment ToDomain(EnrollmentRow r) =>
        DEnrollment.Reconstitute(
            r.Id,
            new EnrollmentCode(r.Code, r.CodeNumber),
            r.StudentId,
            new AcademicPlacement(r.LevelId, r.GradeId, r.ShiftId, r.SectionId),
            r.SchoolFeeConceptId,
            r.SchoolYearId,
            r.PreviousSchool,
            r.EnrollmentDate,
            r.StateName switch
            {
                EnrollmentStateNames.Cancelled  => EnrollmentStatus.Cancelled,
                EnrollmentStateNames.Withdrawn  => EnrollmentStatus.Withdrawn,
                EnrollmentStateNames.Finalized  => EnrollmentStatus.Finalized,
                _                               => EnrollmentStatus.Active
            });

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
        public DateOnly EnrollmentDate { get; set; }
        public string StateName { get; set; } = null!;
    }
}
