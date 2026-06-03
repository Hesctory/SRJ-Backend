using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Domain.Constants;
using SRJBackend.Domain.Entities;

namespace SRJBackend.Application.UseCases;

public class CreatePaymentPreviewUseCase
{
    private readonly IEnrollmentDebtRepository _debtRepository;
    private readonly IPaymentPreviewCache _cache;

    public CreatePaymentPreviewUseCase(IEnrollmentDebtRepository debtRepository, IPaymentPreviewCache cache)
    {
        _debtRepository = debtRepository;
        _cache = cache;
    }

    public async Task<PaymentPreviewResponseDTO> ExecuteAsync(PaymentPreviewRequestDTO dto)
    {
        var debts = await _debtRepository.GetPayableDebtsAsync(dto.EnrollmentId, dto.EnrollmentDebtId);
        var payment = DPayment.Allocate(dto.EnrollmentId, dto.PaymentMethodId, dto.Date, dto.Amount, dto.Reference, debts);

        var cachedPlan = new CachedPaymentPlan(
            EnrollmentId: payment.EnrollmentId,
            PaymentMethodId: payment.PaymentMethodId,
            PaymentDate: payment.Date,
            Amount: payment.Amount,
            NOperation: payment.NOperation,
            Lines: payment.Lines.Select(l => new CachedPaymentPlanLine(
                l.DebtId, l.Description, l.Allocated, l.RemainingAfter,
                DebtStatusCodes.FromEnum(l.NewStatus))).ToList(),
            TotalAllocated: payment.TotalAllocated,
            Change: payment.Change);

        var token = _cache.Store(cachedPlan);

        var planDto = new PaymentPlanDTO(
            Lines: payment.Lines.Select(l => new PaymentPlanLineDTO(
                l.DebtId, l.Description, l.Allocated, l.RemainingAfter)).ToList(),
            TotalAllocated: payment.TotalAllocated,
            Change: payment.Change);

        return new PaymentPreviewResponseDTO(token, planDto);
    }
}
