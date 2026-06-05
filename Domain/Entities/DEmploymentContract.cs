using SRJBackend.Domain.Exceptions;

namespace SRJBackend.Domain.Entities;

public class DEmploymentContract
{
    public int Id { get; private set; }
    public int StaffMemberId { get; private set; }
    public int InstitutionId { get; private set; }
    public int SchoolYearId { get; private set; }
    public int JobPositionId { get; private set; }
    public int? AreaId { get; private set; }
    public DateOnly StartDate { get; private set; }
    public DateOnly? EndDate { get; private set; }
    public decimal? Salary { get; private set; }

    public static DEmploymentContract Create(
        int staffMemberId,
        int institutionId,
        int schoolYearId,
        int jobPositionId,
        int? areaId,
        DateOnly startDate,
        DateOnly? endDate,
        decimal? salary)
    {
        if (staffMemberId <= 0) throw new ArgumentException("Staff member is required.", nameof(staffMemberId));
        if (institutionId <= 0) throw new ArgumentException("Institution is required.", nameof(institutionId));
        if (schoolYearId <= 0) throw new ArgumentException("School year is required.", nameof(schoolYearId));
        if (jobPositionId <= 0) throw new ArgumentException("Job position is required.", nameof(jobPositionId));
        if (startDate == default) throw new ArgumentException("Start date is required.", nameof(startDate));
        if (endDate.HasValue && endDate.Value <= startDate)
            throw new DomainException("La fecha de fin debe ser posterior a la fecha de inicio.");

        return new DEmploymentContract(0, staffMemberId, institutionId, schoolYearId, jobPositionId,
                                       areaId, startDate, endDate, salary);
    }

    internal static DEmploymentContract Reconstitute(
        int id,
        int staffMemberId,
        int institutionId,
        int schoolYearId,
        int jobPositionId,
        int? areaId,
        DateOnly startDate,
        DateOnly? endDate,
        decimal? salary)
        => new DEmploymentContract(id, staffMemberId, institutionId, schoolYearId, jobPositionId,
                                   areaId, startDate, endDate, salary);

    public void Update(
        int institutionId,
        int schoolYearId,
        int jobPositionId,
        int? areaId,
        DateOnly startDate,
        DateOnly? endDate,
        decimal? salary)
    {
        if (institutionId <= 0) throw new ArgumentException("Institution is required.", nameof(institutionId));
        if (schoolYearId <= 0) throw new ArgumentException("School year is required.", nameof(schoolYearId));
        if (jobPositionId <= 0) throw new ArgumentException("Job position is required.", nameof(jobPositionId));
        if (startDate == default) throw new ArgumentException("Start date is required.", nameof(startDate));
        if (endDate.HasValue && endDate.Value <= startDate)
            throw new DomainException("La fecha de fin debe ser posterior a la fecha de inicio.");

        InstitutionId = institutionId;
        SchoolYearId = schoolYearId;
        JobPositionId = jobPositionId;
        AreaId = areaId;
        StartDate = startDate;
        EndDate = endDate;
        Salary = salary;
    }

    private DEmploymentContract(
        int id,
        int staffMemberId,
        int institutionId,
        int schoolYearId,
        int jobPositionId,
        int? areaId,
        DateOnly startDate,
        DateOnly? endDate,
        decimal? salary)
    {
        Id = id;
        StaffMemberId = staffMemberId;
        InstitutionId = institutionId;
        SchoolYearId = schoolYearId;
        JobPositionId = jobPositionId;
        AreaId = areaId;
        StartDate = startDate;
        EndDate = endDate;
        Salary = salary;
    }
}
