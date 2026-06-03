using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Domain.Constants;
using SRJBackend.Domain.Entities;

namespace SRJBackend.Application.UseCases;

public class ConfirmPaymentUseCase
{
    private readonly IPaymentRepository _paymentRepository;
    private readonly IPaymentPreviewCache _cache;
    private readonly IUnitOfWork _unitOfWork;

    public ConfirmPaymentUseCase(
        IPaymentRepository paymentRepository,
        IPaymentPreviewCache cache,
        IUnitOfWork unitOfWork)
    {
        _paymentRepository = paymentRepository;
        _cache = cache;
        _unitOfWork = unitOfWork;
    }

    public async Task<ConfirmPaymentResponseDTO> ExecuteAsync(string previewToken)
    {
        if (!_cache.TryGet(previewToken, out CachedPaymentPlan? plan) || plan is null)
            throw new KeyNotFoundException("El token de pago no es válido o ha expirado.");

        var lines = plan.Lines
            .Select(l => new DPaymentLine(
                l.DebtId, l.Description, l.Allocated, l.RemainingAfter,
                DebtStatusCodes.ToEnum(l.NewStatusCode)))
            .ToList();

        var payment = DPayment.Reconstitute(
            plan.EnrollmentId, plan.PaymentMethodId, plan.PaymentDate,
            plan.Amount, plan.NOperation, lines, plan.TotalAllocated, plan.Change);

        await _unitOfWork.BeginAsync();
        int paymentId;
        try
        {
            paymentId = await _paymentRepository.CreateAsync(payment);
            await _unitOfWork.CommitAsync();
            _cache.Remove(previewToken);
        }
        catch
        {
            await _unitOfWork.RollbackAsync();
            throw;
        }

        var planDto = new PaymentPlanDTO(
            Lines: plan.Lines.Select(l => new PaymentPlanLineDTO(
                l.DebtId, l.Description, l.Allocated, l.RemainingAfter)).ToList(),
            TotalAllocated: plan.TotalAllocated,
            Change: plan.Change);

        return new ConfirmPaymentResponseDTO(paymentId, planDto);
    }
}
