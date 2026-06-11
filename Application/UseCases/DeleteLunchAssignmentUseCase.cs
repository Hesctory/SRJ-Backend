using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class DeleteLunchAssignmentUseCase
{
    private readonly ILunchAssignmentRepository _repository;

    public DeleteLunchAssignmentUseCase(ILunchAssignmentRepository repository)
    {
        _repository = repository;
    }

    public async Task<bool> ExecuteAsync(int id)
    {
        var assignment = await _repository.GetByIdAsync(id);
        if (assignment == null) return false;

        if (assignment.DebtPaidAmount > 0)
            throw new InvalidOperationException("No se puede eliminar una asignación con pagos registrados.");

        return await _repository.DeleteAsync(id);
    }
}
