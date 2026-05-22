using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class DeleteEnrollmentUseCase
{
    private readonly IEnrollmentRepository _enrollmentRepository;
    private readonly IEnrollmentQueries _enrollmentQueries;
    private readonly IStudentRepository _studentRepository;
    private readonly IUnitOfWork _unitOfWork;

    public DeleteEnrollmentUseCase(
        IEnrollmentRepository enrollmentRepository,
        IEnrollmentQueries enrollmentQueries,
        IStudentRepository studentRepository,
        IUnitOfWork unitOfWork)
    {
        _enrollmentRepository = enrollmentRepository;
        _enrollmentQueries = enrollmentQueries;
        _studentRepository = studentRepository;
        _unitOfWork = unitOfWork;
    }

    public async Task<bool> ExecuteAsync(int id)
    {
        var enrollment = await _enrollmentRepository.GetByIdAsync(id);
        if (enrollment == null) return false;

        await _unitOfWork.BeginAsync();
        try
        {
            var cancelled = await _enrollmentRepository.CancelAsync(id);
            if (!cancelled)
            {
                await _unitOfWork.RollbackAsync();
                return false;
            }

            var hasValid = await _enrollmentQueries.HasValidEnrollmentsAsync(enrollment.StudentId);
            if (!hasValid)
                await _studentRepository.ArchiveAsync(enrollment.StudentId);

            await _unitOfWork.CommitAsync();
        }
        catch
        {
            await _unitOfWork.RollbackAsync();
            throw;
        }

        return true;
    }
}
