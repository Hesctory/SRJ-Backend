using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Domain.Entities;

namespace SRJBackend.Application.UseCases;

public class RecordLunchPaymentUseCase
{
    private readonly ILunchAssignmentRepository _repository;
    private readonly IUnitOfWork _unitOfWork;

    public RecordLunchPaymentUseCase(
        ILunchAssignmentRepository repository,
        IUnitOfWork unitOfWork)
    {
        _repository = repository;
        _unitOfWork = unitOfWork;
    }

    public async Task<LunchPaymentResultDTO> ExecuteAsync(RecordLunchPaymentDTO dto)
    {
        if (!await _repository.PersonExistsAsync(dto.PersonId))
            throw new KeyNotFoundException("La persona indicada no existe.");

        var assignments = await _repository.GetUnpaidByPersonAsync(dto.PersonId);

        var payment = DLunchPayment.Allocate(dto.PersonId, dto.Date, dto.Amount, assignments);

        await _unitOfWork.BeginAsync();
        try
        {
            var paidAssignmentIds = payment.Lines.Select(l => l.AssignmentId).ToHashSet();
            await _repository.UpdateDebtPaymentsAsync(
                assignments.Where(a => paidAssignmentIds.Contains(a.Id)).ToList());
            await _unitOfWork.CommitAsync();
        }
        catch
        {
            await _unitOfWork.RollbackAsync();
            throw;
        }

        return new LunchPaymentResultDTO(
            Lines: payment.Lines.Select(l => new LunchPaymentLineDTO(
                l.AssignmentId, l.AssignedDate, l.LunchName,
                l.Applied, l.RemainingAfter, l.IsSettled)).ToList(),
            TotalAllocated: payment.TotalAllocated,
            Change: payment.Change);
    }
}
