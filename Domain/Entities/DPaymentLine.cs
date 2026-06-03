namespace SRJBackend.Domain.Entities;

public record DPaymentLine(
    long DebtId,
    string Description,
    decimal Allocated,
    decimal RemainingAfter,
    DebtStatus NewStatus);
