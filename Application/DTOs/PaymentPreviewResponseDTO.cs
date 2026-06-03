namespace SRJBackend.Application.DTOs;

public record PaymentPlanLineDTO(
    long DebtId,
    string Description,
    decimal Allocated,
    decimal Remaining);

public record PaymentPlanDTO(
    List<PaymentPlanLineDTO> Lines,
    decimal TotalAllocated,
    decimal Change);

public record PaymentPreviewResponseDTO(string PreviewToken, PaymentPlanDTO PaymentPlan);
