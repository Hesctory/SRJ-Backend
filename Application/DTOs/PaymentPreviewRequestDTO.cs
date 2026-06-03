namespace SRJBackend.Application.DTOs;

public record PaymentPreviewRequestDTO(
    int EnrollmentId,
    long? EnrollmentDebtId,
    decimal Amount,
    int PaymentMethodId,
    DateOnly Date,
    string? Reference);
