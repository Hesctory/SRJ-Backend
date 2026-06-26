using SRJBackend.Domain.Exceptions;
using SRJBackend.Domain.ValueObjects;

namespace SRJBackend.Domain.Entities;

public class DEnrollment
{
    public int Id { get; private set; }
    public EnrollmentCode Code { get; private set; }
    public int StudentId { get; private set; }
    public AcademicPlacement Placement { get; private set; }
    public int SchoolFeeConceptId { get; private set; }
    public int SchoolYearId { get; private set; }
    public string? PreviousSchool { get; private set; }
    public DateOnly EnrollmentDate { get; private set; }
    public EnrollmentStatus Status { get; private set; }

    public static DEnrollment Create(
        EnrollmentCode code,
        int studentId,
        AcademicPlacement placement,
        int schoolFeeConceptId,
        DSchoolYear schoolYear,
        string? previousSchool,
        DateOnly? enrollmentDate = null)
    {
        if (studentId <= 0)
            throw new ArgumentException("El identificador del estudiante es inválido.", nameof(studentId));
        if (schoolFeeConceptId <= 0)
            throw new ArgumentException("El concepto de pago es requerido.", nameof(schoolFeeConceptId));
        if (!schoolYear.IsActive)
            throw new DomainException("No se puede matricular en un año escolar que no está activo.");

        return new DEnrollment(0, code, studentId, placement, schoolFeeConceptId, schoolYear.Id, previousSchool, enrollmentDate ?? DateOnly.FromDateTime(DateTime.Today), EnrollmentStatus.Active);
    }

    public void Update(AcademicPlacement placement, int schoolFeeConceptId, DSchoolYear schoolYear, string? previousSchool)
    {
        if (!schoolYear.IsActive)
            throw new DomainException("No se puede modificar una matrícula de un año escolar que no está activo.");
        if (schoolFeeConceptId <= 0)
            throw new ArgumentException("El concepto de pago es requerido.", nameof(schoolFeeConceptId));

        Placement = placement;
        SchoolFeeConceptId = schoolFeeConceptId;
        PreviousSchool = previousSchool;
    }

    public void Cancel(DSchoolYear schoolYear)
    {
        if (!schoolYear.IsActive)
            throw new DomainException("No se puede cancelar una matrícula de un año escolar que no está activo.");
        Status = EnrollmentStatus.Cancelled;
    }

    public void Withdraw(DSchoolYear schoolYear)
    {
        if (!schoolYear.IsActive)
            throw new DomainException("No se puede retirar una matrícula de un año escolar que no está activo.");
        if (Status != EnrollmentStatus.Active)
            throw new DomainException("Solo se puede retirar una matrícula activa.");
        Status = EnrollmentStatus.Withdrawn;
    }

    public void Reactivate(DSchoolYear schoolYear)
    {
        if (!schoolYear.IsActive)
            throw new DomainException("No se puede reactivar una matrícula de un año escolar que no está activo.");
        Status = EnrollmentStatus.Active;
    }

    internal static DEnrollment Reconstitute(
        int id,
        EnrollmentCode code,
        int studentId,
        AcademicPlacement placement,
        int schoolFeeConceptId,
        int schoolYearId,
        string? previousSchool,
        DateOnly enrollmentDate,
        EnrollmentStatus status)
        => new DEnrollment(id, code, studentId, placement, schoolFeeConceptId, schoolYearId, previousSchool, enrollmentDate, status);

    private DEnrollment(
        int id,
        EnrollmentCode code,
        int studentId,
        AcademicPlacement placement,
        int schoolFeeConceptId,
        int schoolYearId,
        string? previousSchool,
        DateOnly enrollmentDate,
        EnrollmentStatus status)
    {
        Id = id;
        Code = code;
        StudentId = studentId;
        Placement = placement;
        SchoolFeeConceptId = schoolFeeConceptId;
        SchoolYearId = schoolYearId;
        PreviousSchool = previousSchool;
        EnrollmentDate = enrollmentDate;
        Status = status;
    }
}
