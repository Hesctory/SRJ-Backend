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

    public static DEnrollment Create(
        EnrollmentCode code,
        int studentId,
        AcademicPlacement placement,
        int schoolFeeConceptId,
        DSchoolYear schoolYear,
        string? previousSchool)
    {
        if (studentId <= 0)
            throw new ArgumentException("El identificador del estudiante es inválido.", nameof(studentId));
        if (schoolFeeConceptId <= 0)
            throw new ArgumentException("El concepto de pago es requerido.", nameof(schoolFeeConceptId));
        if (!schoolYear.IsActive)
            throw new DomainException("No se puede matricular en un año escolar que no está activo.");

        return new DEnrollment(0, code, studentId, placement, schoolFeeConceptId, schoolYear.Id, previousSchool);
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

    public void ValidateCanDelete(DSchoolYear schoolYear)
    {
        if (!schoolYear.IsActive)
            throw new DomainException("No se puede eliminar una matrícula de un año escolar que no está activo.");
    }

    internal static DEnrollment Reconstitute(
        int id,
        EnrollmentCode code,
        int studentId,
        AcademicPlacement placement,
        int schoolFeeConceptId,
        int schoolYearId,
        string? previousSchool)
        => new DEnrollment(id, code, studentId, placement, schoolFeeConceptId, schoolYearId, previousSchool);

    private DEnrollment(
        int id,
        EnrollmentCode code,
        int studentId,
        AcademicPlacement placement,
        int schoolFeeConceptId,
        int schoolYearId,
        string? previousSchool)
    {
        Id = id;
        Code = code;
        StudentId = studentId;
        Placement = placement;
        SchoolFeeConceptId = schoolFeeConceptId;
        SchoolYearId = schoolYearId;
        PreviousSchool = previousSchool;
    }
}
