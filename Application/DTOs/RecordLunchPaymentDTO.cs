namespace SRJBackend.Application.DTOs;

public record RecordLunchPaymentDTO(
    int PersonId,
    decimal Amount,
    DateOnly Date);
