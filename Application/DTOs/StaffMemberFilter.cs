namespace SRJBackend.Application.DTOs;

public record StaffMemberFilter(
    string? FullName = null,
    string? DocumentNumber = null,
    string? EmployeeCode = null,
    bool? IsActive = null,
    bool? IsArchived = null
);
