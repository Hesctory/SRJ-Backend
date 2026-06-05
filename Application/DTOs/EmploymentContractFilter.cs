namespace SRJBackend.Application.DTOs;

public record EmploymentContractFilter(
    int? StaffMemberId = null,
    int? SchoolYearId = null,
    int? JobPositionId = null,
    int? AreaId = null
);
