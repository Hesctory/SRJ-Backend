namespace SRJBackend.Application.DTOs;

public record CachedPaymentPlan(
    int EnrollmentId,
    int PaymentMethodId,
    DateOnly PaymentDate,
    decimal Amount,
    string? NOperation,
    List<CachedPaymentPlanLine> Lines,
    decimal TotalAllocated,
    decimal Change);

public record CachedPaymentPlanLine(
    long DebtId,
    string Description,
    decimal Allocated,
    decimal RemainingAfter,
    string NewStatusCode);
