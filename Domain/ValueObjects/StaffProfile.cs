namespace SRJBackend.Domain.ValueObjects;

public record StaffProfile(
    int? LevelOfEducationId,
    string? ProfessionalTitle,
    string? EmployeeCode,
    string? PreviousInstitution,
    string? SpouseName,
    string? SpouseDocumentNumber,
    string? SpouseOccupation,
    short? NumberOfChildren,
    string? Comment
);
