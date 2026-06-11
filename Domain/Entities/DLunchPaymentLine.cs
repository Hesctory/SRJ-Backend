namespace SRJBackend.Domain.Entities;

public record DLunchPaymentLine(
    int AssignmentId,
    DateOnly AssignedDate,
    string? LunchName,
    decimal Applied,
    decimal RemainingAfter,
    bool IsSettled);
