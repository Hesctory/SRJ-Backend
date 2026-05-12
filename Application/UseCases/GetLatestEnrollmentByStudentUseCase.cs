using SRJBackend.Application.Interfaces;
using SRJBackend.Domain.Entities;

namespace SRJBackend.Application.UseCases;

public class GetLatestEnrollmentByStudentUseCase
{
    private readonly IEnrollmentRepository _enrollmentRepository;

    public GetLatestEnrollmentByStudentUseCase(IEnrollmentRepository enrollmentRepository)
    {
        _enrollmentRepository = enrollmentRepository;
    }

    public Task<DEnrollment?> ExecuteAsync(int studentId)
        => _enrollmentRepository.GetLatestByStudentIdAsync(studentId);
}
