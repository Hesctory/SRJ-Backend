using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Domain.Entities;
using SRJBackend.Domain.Exceptions;

namespace SRJBackend.Application.UseCases;

public class CreateLunchAssignmentUseCase
{
    private readonly ILunchAssignmentRepository _repository;
    private readonly ILunchQueries _lunchQueries;

    public CreateLunchAssignmentUseCase(
        ILunchAssignmentRepository repository,
        ILunchQueries lunchQueries)
    {
        _repository = repository;
        _lunchQueries = lunchQueries;
    }

    public async Task<int> ExecuteAsync(CreateLunchAssignmentDTO dto, int? assignedById)
    {
        var lunch = await _lunchQueries.GetByIdAsync(dto.LunchId)
            ?? throw new KeyNotFoundException("El almuerzo indicado no existe.");

        if (lunch.SalePrice is null or <= 0)
            throw new DomainException("El almuerzo no tiene precio de venta configurado.");

        if (!await _repository.PersonExistsAsync(dto.PersonId))
            throw new KeyNotFoundException("La persona indicada no existe.");

        if (dto.EnrollmentId.HasValue
            && !await _repository.EnrollmentBelongsToPersonAsync(dto.EnrollmentId.Value, dto.PersonId))
            throw new KeyNotFoundException("La matrícula no existe o no pertenece a la persona indicada.");

        var assignment = DLunchAssignment.Create(
            dto.PersonId, dto.EnrollmentId, dto.LunchId,
            dto.AssignedDate, lunch.SalePrice.Value, assignedById, dto.IsPaid);

        return await _repository.CreateAsync(assignment);
    }
}
