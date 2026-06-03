namespace SRJBackend.Application.DTOs;

public record EnrollmentDebtDTO(
    long Id,
    int EnrollmentId,
    string? Description,
    decimal TotalAmount,
    decimal PaidAmount,
    DateOnly DueDate,
    string Status);
