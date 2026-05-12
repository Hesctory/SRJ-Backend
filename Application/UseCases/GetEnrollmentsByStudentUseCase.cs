using SRJBackend.Application.Interfaces;
using SRJBackend.Domain.Entities;

namespace SRJBackend.Application.UseCases;

public class GetEnrollmentsByStudentUseCase
{
    private readonly IEnrollmentRepository _enrollmentRepository;

    public GetEnrollmentsByStudentUseCase(IEnrollmentRepository enrollmentRepository)
    {
        _enrollmentRepository = enrollmentRepository;
    }

    public Task<List<DEnrollment>> ExecuteAsync(int studentId)
        => _enrollmentRepository.GetByStudentIdAsync(studentId);
}
