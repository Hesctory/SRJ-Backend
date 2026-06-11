namespace SRJBackend.Application.DTOs;

public record LunchPaymentResultDTO(
    List<LunchPaymentLineDTO> Lines,
    decimal TotalAllocated,
    decimal Change);

public record LunchPaymentLineDTO(
    int AssignmentId,
    DateOnly AssignedDate,
    string? LunchName,
    decimal Applied,
    decimal RemainingAfter,
    bool IsSettled);
