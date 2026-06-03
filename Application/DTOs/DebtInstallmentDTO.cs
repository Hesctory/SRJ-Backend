namespace SRJBackend.Application.DTOs;

public record DebtInstallmentDTO(
    long Id,
    long DebtId,
    decimal Amount,
    DateOnly Date,
    string PaymentMethodName,
    string? Reference);
