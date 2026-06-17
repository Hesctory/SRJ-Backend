using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Domain.Entities;
using SRJBackend.Domain.Exceptions;

namespace SRJBackend.Application.UseCases;

public class CreateLunchAssignmentUseCase
{
    private readonly ILunchAssignmentRepository _repository;
    private readonly ILunchRepository _lunchRepository;

    public CreateLunchAssignmentUseCase(
        ILunchAssignmentRepository repository,
        ILunchRepository lunchRepository)
    {
        _repository = repository;
        _lunchRepository = lunchRepository;
    }

    public async Task<List<int>> ExecuteAsync(CreateLunchAssignmentDTO dto, int? assignedById)
    {
        if (dto.LunchIds is null || dto.LunchIds.Count == 0)
            throw new DomainException("Debe indicar al menos una lonchera.");

        if (!await _repository.PersonExistsAsync(dto.PersonId))
            throw new KeyNotFoundException("La persona indicada no existe.");

        if (!await _repository.ShiftExistsAsync(dto.ShiftId))
            throw new KeyNotFoundException("El turno indicado no existe.");

        if (dto.EnrollmentId.HasValue
            && !await _repository.EnrollmentBelongsToPersonAsync(dto.EnrollmentId.Value, dto.PersonId))
            throw new KeyNotFoundException("La matrícula no existe o no pertenece a la persona indicada.");

        var assignments = new List<DLunchAssignment>(dto.LunchIds.Count);
        var remaining = dto.AmountPaid ?? 0m;

        foreach (var lunchId in dto.LunchIds)
        {
            var lunch = await _lunchRepository.GetByIdAsync(lunchId)
                ?? throw new KeyNotFoundException($"La lonchera con id {lunchId} no existe.");

            if (!lunch.IsAssignable)
                throw new DomainException($"La lonchera '{lunch.LunchName}' no tiene precio de venta configurado.");

            var paidForThis = Math.Min(remaining, lunch.SalePrice!.Value);
            remaining -= paidForThis;

            assignments.Add(DLunchAssignment.Create(
                dto.PersonId, dto.EnrollmentId, lunchId, dto.ShiftId,
                dto.AssignedDate, lunch.SalePrice.Value, assignedById,
                paidForThis > 0m ? paidForThis : null));
        }

        return await _repository.CreateManyAsync(assignments);
    }
}
