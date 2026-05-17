using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class DeleteEnrollmentUseCase
{
    private readonly IEnrollmentRepository _enrollmentRepository;

    public DeleteEnrollmentUseCase(IEnrollmentRepository enrollmentRepository)
    {
        _enrollmentRepository = enrollmentRepository;
    }

    public async Task<bool> ExecuteAsync(int id)
    {
        return await _enrollmentRepository.DeleteAsync(id);
    }
}
